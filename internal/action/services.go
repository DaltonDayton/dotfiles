package action

import (
	"fmt"
	"os/exec"
	"strings"
)

// systemctl is overridable for tests — real calls go to the binary, fakes
// are injected by swapping this var.
var systemctl = func(args ...string) (string, error) {
	out, err := exec.Command("systemctl", args...).CombinedOutput()
	return string(out), err
}

// Service ensures a systemd unit reaches a desired state.
type Service struct {
	Name  string
	Scope string // "user" | "system"
	State string // "enabled" | "started" | "enabled+started"
}

func (s *Service) Describe() string {
	return fmt.Sprintf("systemd %s unit %s -> %s", s.Scope, s.Name, s.State)
}

func (s *Service) scopeArgs() []string {
	if s.Scope == "user" {
		return []string{"--user"}
	}
	return nil
}

func (s *Service) isEnabled() (bool, error) {
	args := append(s.scopeArgs(), "is-enabled", s.Name)
	out, err := systemctl(args...)
	out = strings.TrimSpace(out)
	if err != nil {
		// why: systemctl returns nonzero for "disabled"/"masked"/"static"/"linked" —
		// that's a normal "not in desired state" signal, not a tool failure. "linked"
		// means the unit file is symlinked in but lacks WantedBy enablement symlinks,
		// so enable still needs to run.
		switch out {
		case "disabled", "masked", "static", "linked", "linked-runtime":
			return false, nil
		}
		return false, fmt.Errorf("is-enabled: %w (output: %s)", err, out)
	}
	return out == "enabled" || out == "alias", nil
}

func (s *Service) isActive() (bool, error) {
	args := append(s.scopeArgs(), "is-active", s.Name)
	out, err := systemctl(args...)
	out = strings.TrimSpace(out)
	if err != nil {
		if out == "inactive" || out == "failed" {
			return false, nil
		}
		return false, fmt.Errorf("is-active: %w (output: %s)", err, out)
	}
	return out == "active", nil
}

func (s *Service) Check() (bool, error) {
	needEnabled := strings.Contains(s.State, "enabled")
	needStarted := strings.Contains(s.State, "started")
	if needEnabled {
		ok, err := s.isEnabled()
		if err != nil || !ok {
			return false, err
		}
	}
	if needStarted {
		ok, err := s.isActive()
		if err != nil || !ok {
			return false, err
		}
	}
	return true, nil
}

func (s *Service) Apply() error {
	needEnabled := strings.Contains(s.State, "enabled")
	needStarted := strings.Contains(s.State, "started")
	if needEnabled {
		args := append(s.scopeArgs(), "enable", s.Name)
		if out, err := systemctl(args...); err != nil {
			return fmt.Errorf("enable: %w (%s)", err, out)
		}
	}
	if needStarted {
		args := append(s.scopeArgs(), "start", s.Name)
		if out, err := systemctl(args...); err != nil {
			return fmt.Errorf("start: %w (%s)", err, out)
		}
	}
	return nil
}
