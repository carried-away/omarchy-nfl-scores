import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
STORAGE = ROOT / "bin" / "omarchy-nflscores-storage"
MAX_CACHE_BYTES = 131072
MAX_FAVORITES_BYTES = 4096


class StorageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir(mode=0o700)
        self.env = os.environ.copy()
        self.env["HOME"] = str(self.home)
        self.env["XDG_CACHE_HOME"] = str(self.home / ".cache")

    def tearDown(self):
        self.temp.cleanup()

    def run_storage(self, *args, input_text=None):
        return subprocess.run(
            [sys.executable, str(STORAGE), *args],
            input=input_text,
            text=True,
            capture_output=True,
            env=self.env,
            check=False,
        )

    def test_favorites_read_and_atomic_write(self):
        saved = self.run_storage("write-favorites", '{"favorites":["BUF","SF"]}')
        self.assertEqual(saved.returncode, 0, saved.stderr)

        loaded = self.run_storage("read-favorites")
        self.assertEqual(loaded.returncode, 0, loaded.stderr)
        self.assertEqual(json.loads(loaded.stdout), {"favorites": ["BUF", "SF"]})

        path = self.home / ".local/state/omarchy/settings/nflscores.json"
        self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_favorites_reject_symlink_for_read_and_write(self):
        target = self.root / "private.json"
        target.write_text('{"private":"sentinel"}')
        path = self.home / ".local/state/omarchy/settings/nflscores.json"
        path.parent.mkdir(parents=True)
        path.symlink_to(target)

        read = self.run_storage("read-favorites")
        self.assertNotEqual(read.returncode, 0)
        self.assertEqual(read.stdout, "")

        write = self.run_storage("write-favorites", '{"favorites":["BUF"]}')
        self.assertNotEqual(write.returncode, 0)
        self.assertEqual(target.read_text(), '{"private":"sentinel"}')

    def test_favorites_reject_oversized_file(self):
        path = self.home / ".local/state/omarchy/settings/nflscores.json"
        path.parent.mkdir(parents=True)
        path.write_bytes(b" " * (MAX_FAVORITES_BYTES + 1))

        read = self.run_storage("read-favorites")
        self.assertNotEqual(read.returncode, 0)
        self.assertEqual(read.stdout, "")

    def test_favorites_reject_hard_link(self):
        path = self.home / ".local/state/omarchy/settings/nflscores.json"
        path.parent.mkdir(parents=True)
        path.write_text('{"favorites":["BUF"]}')
        linked = self.root / "linked-favorites.json"
        os.link(path, linked)

        read = self.run_storage("read-favorites")
        self.assertNotEqual(read.returncode, 0)
        self.assertEqual(read.stdout, "")

    def test_cache_read_write_and_symlink_protection(self):
        saved = self.run_storage("write-cache", input_text='{"events":[]}\n')
        self.assertEqual(saved.returncode, 0, saved.stderr)

        loaded = self.run_storage("read-cache")
        self.assertEqual(loaded.returncode, 0, loaded.stderr)
        self.assertEqual(json.loads(loaded.stdout), {"events": []})

        cache = self.home / ".cache/omarchy/nflscores.json"
        cache.unlink()
        target = self.root / "cache-target.json"
        target.write_text('{"events":[],"sentinel":"unchanged"}\n')
        cache.symlink_to(target)

        read = self.run_storage("read-stale-cache")
        self.assertNotEqual(read.returncode, 0)
        self.assertEqual(read.stdout, "")

        write = self.run_storage("write-cache", input_text='{"events":[]}\n')
        self.assertNotEqual(write.returncode, 0)
        self.assertEqual(target.read_text(), '{"events":[],"sentinel":"unchanged"}\n')

    def test_cache_rejects_oversized_file(self):
        cache = self.home / ".cache/omarchy/nflscores.json"
        cache.parent.mkdir(parents=True)
        cache.write_bytes(b" " * (MAX_CACHE_BYTES + 1))

        read = self.run_storage("read-stale-cache")
        self.assertNotEqual(read.returncode, 0)
        self.assertEqual(read.stdout, "")

    def test_favorites_path_rejects_symlinked_parent(self):
        outside = self.root / "outside"
        outside.mkdir()
        (self.home / ".local").symlink_to(outside, target_is_directory=True)

        read = self.run_storage("read-favorites")
        self.assertNotEqual(read.returncode, 0)
        write = self.run_storage("write-favorites", '{"favorites":["BUF"]}')
        self.assertNotEqual(write.returncode, 0)
        self.assertEqual(list(outside.iterdir()), [])

    def test_cache_rejects_group_writable_storage_directory(self):
        cache_dir = self.home / ".cache/omarchy"
        cache_dir.mkdir(parents=True)
        cache_dir.chmod(0o770)

        read = self.run_storage("read-stale-cache")
        self.assertNotEqual(read.returncode, 0)
        self.assertEqual(read.stdout, "")


if __name__ == "__main__":
    unittest.main()
