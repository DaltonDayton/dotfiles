package main

import (
	"fmt"

	"github.com/spf13/cobra"
)

func newListCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "List all discovered modules",
		RunE: func(cmd *cobra.Command, args []string) error {
			ctx, err := loadCtx()
			if err != nil {
				return err
			}
			for _, m := range ctx.Modules {
				fmt.Printf("%-20s %s\n", m.Name, m.Description)
			}
			return nil
		},
	}
}
