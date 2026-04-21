package action

import (
	"os"
	"path/filepath"
	"testing"
)

func TestCommand_skipsWhenCheckPasses(t *testing.T) {
	c := &Command{Run: "false", CheckCmd: "true"}
	ok, err := c.Check()
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("Check should be true when CheckCmd exits 0")
	}
}

func TestCommand_runsWhenCheckFails(t *testing.T) {
	dir := t.TempDir()
	marker := filepath.Join(dir, "touched")
	c := &Command{
		Run:      "touch " + marker,
		CheckCmd: "test -f " + marker,
	}

	ok, err := c.Check()
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Fatal("Check should be false before Apply")
	}
	if err := c.Apply(); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(marker); err != nil {
		t.Fatalf("marker not created: %v", err)
	}
	// After Apply, Check should now pass (idempotent on re-run).
	ok, err = c.Check()
	if err != nil {
		t.Fatal(err)
	}
	if !ok {
		t.Fatal("Check should be true after successful Apply")
	}
}

func TestCommand_noCheckAlwaysRuns(t *testing.T) {
	c := &Command{Run: "true"}
	ok, err := c.Check()
	if err != nil {
		t.Fatal(err)
	}
	if ok {
		t.Fatal("Check should be false when no CheckCmd is supplied")
	}
}

func TestCommand_applyPropagatesFailure(t *testing.T) {
	c := &Command{Run: "false"} // always exits 1
	err := c.Apply()
	if err == nil {
		t.Fatal("expected Apply to fail when Run exits non-zero")
	}
}

func TestCommand_satisfiesActionInterface(t *testing.T) {
	var _ Action = (*Command)(nil)
}
