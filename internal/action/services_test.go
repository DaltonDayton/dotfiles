package action

import (
	"errors"
	"testing"
)

type fakeSystemctl struct {
	responses map[string]struct {
		out string
		err error
	}
	calls [][]string
}

func (f *fakeSystemctl) fn(args ...string) (string, error) {
	f.calls = append(f.calls, args)
	key := ""
	for _, a := range args {
		key += a + " "
	}
	if r, ok := f.responses[key]; ok {
		return r.out, r.err
	}
	return "", nil
}

func withFake(t *testing.T, f *fakeSystemctl) {
	t.Helper()
	orig := systemctl
	systemctl = f.fn
	t.Cleanup(func() { systemctl = orig })
}

func TestService_checkAlreadyEnabled(t *testing.T) {
	f := &fakeSystemctl{responses: map[string]struct {
		out string
		err error
	}{
		"--user is-enabled hyprpaper.service ": {out: "enabled\n"},
	}}
	withFake(t, f)

	s := &Service{Name: "hyprpaper.service", Scope: "user", State: "enabled"}
	ok, err := s.Check()
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("expected Check=true for enabled service")
	}
}

func TestService_checkLinkedNeedsEnable(t *testing.T) {
	// A unit symlinked into the user unit dir reports "linked" with a nonzero
	// exit — present but not yet enabled, so Check must return false (not error).
	f := &fakeSystemctl{responses: map[string]struct {
		out string
		err error
	}{
		"--user is-enabled hyprlock-watch.service ": {out: "linked\n", err: errors.New("exit status 1")},
	}}
	withFake(t, f)

	s := &Service{Name: "hyprlock-watch.service", Scope: "user", State: "enabled"}
	ok, err := s.Check()
	if err != nil {
		t.Fatalf("expected no error for linked unit, got %v", err)
	}
	if ok {
		t.Fatal("expected Check=false for linked-but-not-enabled service")
	}
}

func TestService_applyEnablesAndStarts(t *testing.T) {
	f := &fakeSystemctl{}
	withFake(t, f)

	s := &Service{Name: "foo.service", Scope: "system", State: "enabled+started"}
	if err := s.Apply(); err != nil {
		t.Fatal(err)
	}
	if len(f.calls) != 2 {
		t.Fatalf("expected 2 systemctl calls, got %d", len(f.calls))
	}
	if f.calls[0][0] != "enable" || f.calls[1][0] != "start" {
		t.Errorf("calls = %v", f.calls)
	}
}

func TestService_satisfiesActionInterface(t *testing.T) {
	var _ Action = (*Service)(nil)
}
