package host

import (
	"os"
	"path/filepath"
	"testing"
)

func TestDetectOSFromFile(t *testing.T) {
	cases := []struct {
		name    string
		content string
		want    string
	}{
		{"arch", "NAME=\"Arch Linux\"\nID=arch\n", "arch"},
		{"ubuntu", "NAME=\"Ubuntu\"\nID=ubuntu\nVERSION_ID=\"24.04\"\n", "ubuntu"},
		{"ubuntu derivative via ID_LIKE", "ID=pop\nID_LIKE=ubuntu debian\n", "ubuntu"},
		{"debian via ID_LIKE only", "ID=somedeb\nID_LIKE=debian\n", "ubuntu"},
		{"quoted id", "ID=\"ubuntu\"\n", "ubuntu"},
		{"unknown returns raw id", "ID=void\n", "void"},
		{"empty returns unknown", "", "unknown"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			p := filepath.Join(t.TempDir(), "os-release")
			if err := os.WriteFile(p, []byte(c.content), 0o644); err != nil {
				t.Fatal(err)
			}
			if got := detectOSFromFile(p); got != c.want {
				t.Fatalf("detectOSFromFile = %q, want %q", got, c.want)
			}
		})
	}
}

func TestDetectOSMissingFile(t *testing.T) {
	if got := detectOSFromFile(filepath.Join(t.TempDir(), "nope")); got != "unknown" {
		t.Fatalf("missing file = %q, want unknown", got)
	}
}
