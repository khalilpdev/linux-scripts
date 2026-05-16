package fixssh

import (
	"fmt"
	"os"
	"path/filepath"
)

func Execute() error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}

	targets := []struct {
		path string
		mode os.FileMode
	}{
		{path: filepath.Join(home, ".ssh"), mode: 0o700},
		{path: filepath.Join(home, ".ssh", "id_ed25519"), mode: 0o600},
		{path: filepath.Join(home, ".ssh", "id_ed25519.pub"), mode: 0o644},
	}

	for _, target := range targets {
		if err := os.Chmod(target.path, target.mode); err != nil {
			return fmt.Errorf("chmod %s: %w", target.path, err)
		}
	}

	return nil
}
