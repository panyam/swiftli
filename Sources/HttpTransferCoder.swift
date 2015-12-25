
import SwiftIO

/**
 * Handles transfer encoding of a stream and writes the data to the underlying writer
 */
public protocol HttpTransferEncoder : Writer {
    /**
     * The response that is currently being written to.
     */
    var writer: Writer { get set }
}

public class HttpChunkedWriter : Writer {
    var currChunkLength = 0
    var currChunkWritten = 0
    var writer: Writer
    
    public init (writer: Writer)
    {
        self.writer = writer
    }
    
    /**
     * Write from the reader where the data has been chunk encoded as:
     *
     * <length in_hex>CRLF
     * <length bytes of data>CRLF
     */
    public func write(buffer: BufferType, length: Int, callback: IOCallback?) {
        writer.writeString(String(format: "%2X", length) + CRLF, callback: nil)
        // write the payload
        writer.write(buffer, length: length, callback: nil)
        writer.writeString(CRLF, callback: callback)
    }
}

public class HttpChunkedReader : Reader {
    enum ReadState {
        case ReadingLength
        case ReadingChunk
    }
    var reader: BufferedReader
    var readState = ReadState.ReadingLength
    var currChunkLength = 0
    var currChunkRead = 0

    public init (reader: BufferedReader)
    {
        self.reader = reader
    }

    /**
     * Read from the reader where the data has been chunk encoded as:
     *
     * <length in_hex>CRLF
     * <length bytes of data>CRLF
     */
    public func read(buffer: BufferType, length: Int, callback: IOCallback?)
    {
        if readState == ReadState.ReadingLength {
            reader.readTillChar(LF, callback: { (str, error) -> () in
                // we have the length now
                let lengthString = str.substringToIndex(str.endIndex.predecessor())  // remove the \r
                self.currChunkLength = Int(strtoul(lengthString, nil, 16))
                self.currChunkRead = 0
                self.readState = ReadState.ReadingChunk
                // read more
                self.read(buffer, length: length, callback: callback)
            })
        } else {
            // read the actual data chunk now
            let numToRead = min(length, currChunkLength) - currChunkRead
            reader.read(buffer.advancedBy(currChunkRead), length: numToRead, callback: { (length, error) -> () in
                self.currChunkRead += length
                if self.currChunkRead >= self.currChunkLength {
                    // chunk read so reset state
                    self.readState = ReadState.ReadingLength
                    self.reader.readTillChar(LF, callback: nil)
                }
                callback?(length: self.currChunkRead, error: error)
            })
        }
    }
}