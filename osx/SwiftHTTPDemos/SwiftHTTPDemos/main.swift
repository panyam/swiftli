
import SwiftIO

func signal_handler(signum: Int32)
{
    Log.debug("Ignoring Signal: \(signum)")
}

signal(SIGPIPE, signal_handler)

testWSServer()
