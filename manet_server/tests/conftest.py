import os
import tempfile

# Keep tests away from the host's real games, layouts and settings.
os.environ["MANET_DATA_DIR"] = tempfile.mkdtemp(prefix="manet-test-")
