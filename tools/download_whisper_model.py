from __future__ import annotations

from pathlib import Path

from faster_whisper.utils import download_model


destination = Path("models/faster-whisper-small")
download_model("small", output_dir=str(destination))
print(destination.resolve())
