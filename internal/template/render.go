// Package template wraps text/template with the specific options we want
// for rendering host-scoped variables into config files.
package template

import (
	"bytes"
	"fmt"
	"text/template"

	"github.com/DaltonDayton/dotfiles/internal/manifest"
)

// Render executes src as a Go text/template against p.
//
// why: missingkey=error makes typos in .tmpl files fail loudly — a silent
// "<no value>" substitution would produce a broken config that looks fine.
func Render(src string, p *manifest.Profile) (string, error) {
	tmpl, err := template.New("render").Option("missingkey=error").Parse(src)
	if err != nil {
		return "", fmt.Errorf("parse template: %w", err)
	}
	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, p); err != nil {
		return "", fmt.Errorf("execute template: %w", err)
	}
	return buf.String(), nil
}
