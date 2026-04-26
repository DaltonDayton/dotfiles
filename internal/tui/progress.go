package tui

import (
	"fmt"
	"strings"

	"github.com/DaltonDayton/dotfiles/internal/runner"
	tea "github.com/charmbracelet/bubbletea"
)

type moduleLine struct {
	name    string
	total   int // total actions planned for this module
	seen    int // count of terminal events received (done|skipped|error)
	applied int
	skipped int
	failed  int
	current string // action description while running; empty between actions
	err     error  // first error encountered
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
}

type eventMsg runner.Event
type doneMsg struct{}

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

func (m *Model) Init() tea.Cmd { return waitEvent(m.events) }

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
		case runner.EventDone:
			line.seen++
			line.applied++
			line.current = ""
		case runner.EventSkipped:
			line.seen++
			line.skipped++
			line.current = ""
		case runner.EventError:
			line.seen++
			line.failed++
			line.current = ""
			if line.err == nil {
				line.err = msg.Err
			}
		}
		return m, waitEvent(m.events)
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
			icon = "⏳"
			step := l.seen + 1
			if l.total > 0 {
				detail = fmt.Sprintf("[%d/%d] %s", step, l.total, l.current)
			} else {
				detail = l.current
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
