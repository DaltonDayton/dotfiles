package tui

import (
	"fmt"
	"strings"

	"github.com/DaltonDayton/dotfiles/internal/runner"
	tea "github.com/charmbracelet/bubbletea"
)

type moduleLine struct {
	name    string
	actions []string
	status  string
	err     error
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

func NewProgress(order []string, events <-chan runner.Event) *Model {
	m := &Model{
		order:  order,
		byName: map[string]*moduleLine{},
		events: events,
	}
	for _, n := range order {
		m.byName[n] = &moduleLine{name: n, status: "pending"}
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
			line.status = "running"
			line.actions = append(line.actions, msg.Action)
		case runner.EventDone:
			line.status = "done"
		case runner.EventSkipped:
			line.status = "skipped"
		case runner.EventError:
			line.status = "failed"
			line.err = msg.Err
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
		switch l.status {
		case "running":
			icon = "⏳"
		case "done":
			icon = Success.Render("✓")
		case "skipped":
			icon = Subtle.Render("⏭")
		case "failed":
			icon = Error.Render("✗")
		}
		fmt.Fprintf(&b, "%s %-20s %s\n", icon, l.name, Subtle.Render(strings.Join(l.actions, " · ")))
		if l.err != nil {
			fmt.Fprintf(&b, "   %s\n", Error.Render(l.err.Error()))
		}
	}
	return b.String()
}
