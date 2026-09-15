# Artifact persistence — complete-run marker for Bend's File API.
#
# Base exposes File.open/read/write/close but no atomic rename. The writer
# therefore uses a commit marker: report, findings, and manifest are written
# first; the marker is written last. Consumers treat a bundle as committed
# only when the marker exists. A failed/interrupted run cannot publish a new
# completion marker.
import Base

def Art.write_finish(wr: File & Result<&1, &1, U32 & String, Unit>) -> IO(Unit):
  (f2, res) = wr
  do IO<Unit>:
    File.close(f2)
    IO.pass(Unit, res)

def Art.write_path(path: String, data: String) -> IO(Unit):
  do IO<Unit>:
    f : File <- IO.try(File, File.open(path, "w"))
    wr : File & Result<&1, &1, U32 & String, Unit> <- File.write(f, data)
    Art.write_finish(wr)

def Art.marker_data() -> String:
  "complete\n"

def Art.commit(
  reportPath: String,
  jsonlPath: String,
  manifestPath: String,
  markerPath: String,
  report: String,
  jsonl: String,
  manifest: String,
) -> IO(Unit):
  do IO<Unit>:
    Art.write_path(reportPath, report)
    Art.write_path(jsonlPath, jsonl)
    Art.write_path(manifestPath, manifest)
    Art.write_path(markerPath, Art.marker_data())
