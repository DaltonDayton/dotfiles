package tui

import (
	"fmt"
	"strings"
	"time"

	"github.com/DaltonDayton/dotfiles/internal/runner"
	tea "github.com/charmbracelet/bubbletea"
)

type moduleLine struct {
	name      string
	total     int // total actions planned for this module
	seen      int // count of terminal events received (done|skipped|error)
	applied   int
	skipped   int
	failed    int
	current   string    // action description while running; empty between actions
	lastStart time.Time // when the currently running action started; zero when idle
	err       error     // first error encountered
}

func (l *moduleLine) status() string {
	switch {
	case l.failed > 0 && l.seen >= l.total:
		return "failed"
	case l.total > 0 && l.seen >= l.total:
		return "done"
	case l.seen > 0 || l.current != "":
		return "running"
	default:
		return "pending"
	}
}

// Model is a Bubble Tea model that consumes runner.Event values from a
// channel and renders one line per module with current status.
type Model struct {
	order  []string
	byName map[string]*moduleLine
	events <-chan runner.Event
	done   bool
	frame  int // advances on each tickMsg; drives the spinner glyph
}

type eventMsg runner.Event
type doneMsg struct{}
type tickMsg time.Time

// tickInterval drives both the spinner cadence and the elapsed-time refresh.
const tickInterval = 150 * time.Millisecond

// Braille spinner — 10 frames at 150ms reads as smooth motion.
var spinnerFrames = []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}

func tickEvery(d time.Duration) tea.Cmd {
	return tea.Tick(d, func(t time.Time) tea.Msg { return tickMsg(t) })
}

// NewProgress creates a progress model. counts maps module name → total
// number of planned actions, used to render the [X/Y] step counter and the
// final summary. Modules absent from counts default to 0 (no counter shown).
func NewProgress(order []string, counts map[string]int, events <-chan runner.Event) *Model {
	m := &Model{
		order:  order,
		byName: map[string]*moduleLine{},
		events: events,
	}
	for _, n := range order {
		m.byName[n] = &moduleLine{name: n, total: counts[n]}
	}
	return m
}

func (m *Model) Init() tea.Cmd {
	return tea.Batch(waitEvent(m.events), tickEvery(tickInterval))
}

func waitEvent(ch <-chan runner.Event) tea.Cmd {
	return func() tea.Msg {
		e, ok := <-ch
		if !ok {
			return doneMsg{}
		}
		return eventMsg(e)
	}
}

func (m *Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case eventMsg:
		line := m.byName[msg.Module]
		if line == nil {
			return m, waitEvent(m.events)
		}
		switch msg.Kind {
		case runner.EventStart:
			line.current = msg.Action
			line.lastStart = time.Now()
		case runner.EventDone:
			line.seen++
			line.applied++
			line.current = ""
			line.lastStart = time.Time{}
		case runner.EventSkipped:
			line.seen++
			line.skipped++
			line.current = ""
			line.lastStart = time.Time{}
		case runner.EventError:
			line.seen++
			line.failed++
			line.current = ""
			line.lastStart = time.Time{}
			if line.err == nil {
				line.err = msg.Err
			}
		}
		return m, waitEvent(m.events)
	case tickMsg:
		if m.done {
			return m, nil
		}
		m.frame++
		return m, tickEvery(tickInterval)
	case doneMsg:
		m.done = true
		return m, tea.Quit
	}
	return m, nil
}

func (m *Model) View() string {
	var b strings.Builder
	for _, name := range m.order {
		l := m.byName[name]
		icon := "⏸"
		var detail string
		switch l.status() {
		case "running":
			icon = spinnerFrames[m.frame%len(spinnerFrames)]
			step := l.seen + 1
			if l.total > 0 {
				detail = fmt.Sprintf("[%d/%d] %s", step, l.total, l.current)
			} else {
				detail = l.current
			}
			if !l.lastStart.IsZero() {
				if elapsed := time.Since(l.lastStart).Truncate(time.Second); elapsed > 0 {
					detail = fmt.Sprintf("%s · %s", detail, elapsed)
				}
			}
		case "done":
			icon = Success.Render("✓")
			detail = fmt.Sprintf("%d applied · %d skipped", l.applied, l.skipped)
		case "failed":
			icon = Error.Render("✗")
			detail = fmt.Sprintf("%d applied · %d skipped · %d failed", l.applied, l.skipped, l.failed)
		default:
			if l.total > 0 {
				detail = fmt.Sprintf("pending (%d actions)", l.total)
			} else {
				detail = "pending"
			}
		}
		fmt.Fprintf(&b, "%s %-20s %s\n", icon, l.name, Subtle.Render(detail))
		if l.err != nil {
			fmt.Fprintf(&b, "   %s\n", Error.Render(l.err.Error()))
		}
	}
	return b.String()
}
