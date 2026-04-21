package runner

import (
	"github.com/DaltonDayton/dotfiles/internal/action"
)

// EventKind describes the lifecycle phase of an action.
type EventKind string

const (
	EventStart   EventKind = "start"
	EventDone    EventKind = "done"
	EventSkipped EventKind = "skipped"
	EventError   EventKind = "error"
)

// Event is emitted by ApplyActions so a TUI (or plain stdout consumer) can
// observe progress. The runner itself never imports a UI package.
type Event struct {
	Kind   EventKind
	Module string
	Action string
	Err    error
}

// Result is returned per action after ApplyActions finishes.
type Result struct {
	Action string
	Status action.Status
	Err    error
}

// ApplyActions runs Check+Apply for each action in order. It publishes Events
// tagged with moduleName to the channel. Caller must provide a buffered
// channel or drain concurrently — non-blocking sends drop on backpressure.
func ApplyActions(moduleName string, acts []action.Action, events chan<- Event) []Result {
	out := make([]Result, 0, len(acts))
	for _, a := range acts {
		send(events, Event{Kind: EventStart, Module: moduleName, Action: a.Describe()})
		ok, err := a.Check()
		if err != nil {
			out = append(out, Result{Action: a.Describe(), Status: action.StatusFailed, Err: err})
			send(events, Event{Kind: EventError, Module: moduleName, Action: a.Describe(), Err: err})
			continue
		}
		if ok {
			out = append(out, Result{Action: a.Describe(), Status: action.StatusSkipped})
			send(events, Event{Kind: EventSkipped, Module: moduleName, Action: a.Describe()})
			continue
		}
		if err := a.Apply(); err != nil {
			out = append(out, Result{Action: a.Describe(), Status: action.StatusFailed, Err: err})
			send(events, Event{Kind: EventError, Module: moduleName, Action: a.Describe(), Err: err})
			continue
		}
		out = append(out, Result{Action: a.Describe(), Status: action.StatusApplied})
		send(events, Event{Kind: EventDone, Module: moduleName, Action: a.Describe()})
	}
	return out
}

// send drops the event if the channel is full. TUIs are expected to keep up;
// a dropped event is a missed progress line, not a correctness issue.
func send(ch chan<- Event, e Event) {
	if ch == nil {
		return
	}
	select {
	case ch <- e:
	default:
	}
}
