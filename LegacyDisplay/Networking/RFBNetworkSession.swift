import Foundation

public protocol RFBNetworkSessionDelegate: AnyObject {
    func networkSessionDidConnect(_ session: RFBNetworkSession)
    func networkSession(_ session: RFBNetworkSession, didReceiveData data: Data)
    func networkSession(_ session: RFBNetworkSession, didFailWithError error: Error)
    func networkSessionDidClose(_ session: RFBNetworkSession)
}

/// Asynchronous TCP network session compatible with iOS 12.0+ (using CFStream/Stream on dedicated queue).
public final class RFBNetworkSession: NSObject, StreamDelegate {

    public weak var delegate: RFBNetworkSessionDelegate?
    private var inputStream: InputStream?
    private var outputStream: OutputStream?

    private let networkQueue = DispatchQueue(label: "com.legacydisplay.network", qos: .userInitiated)
    private var isConnected = false
    private var isConnecting = false
    private var timeoutTimer: DispatchSourceTimer?
    private let timeoutSeconds: Double = 10.0

    private var writeBuffer = Data()
    private let bufferSize = 16384
    private lazy var readBuffer = [UInt8](repeating: 0, count: bufferSize)

    public func connect(toHost host: String, port: Int) {
        networkQueue.async { [weak self] in
            guard let self = self else { return }
            self.disconnect()
            self.isConnecting = true

            var readStream: Unmanaged<CFReadStream>?
            var writeStream: Unmanaged<CFWriteStream>?

            CFStreamCreatePairWithSocketToHost(
                kCFAllocatorDefault,
                host as CFString,
                UInt32(port),
                &readStream,
                &writeStream
            )

            guard let rStream = readStream?.takeRetainedValue(),
                  let wStream = writeStream?.takeRetainedValue() else {
                self.handleError(NSError(domain: "RFBNetworkSession", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create socket streams"]))
                return
            }

            self.inputStream = rStream as InputStream
            self.outputStream = wStream as OutputStream

            self.inputStream?.delegate = self
            self.outputStream?.delegate = self

            self.inputStream?.schedule(in: .current, forMode: .common)
            self.outputStream?.schedule(in: .current, forMode: .common)

            self.inputStream?.open()
            self.outputStream?.open()

            self.startTimeoutTimer()

            // Run loop for network queue
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }
    }

    public func send(data: Data) {
        networkQueue.async { [weak self] in
            guard let self = self, self.isConnected else { return }
            self.writeBuffer.append(data)
            self.flushWriteBuffer()
        }
    }

    public func disconnect() {
        cancelTimeoutTimer()
        isConnected = false
        isConnecting = false

        if let inStream = inputStream {
            inStream.close()
            inStream.remove(from: .current, forMode: .common)
            inStream.delegate = nil
            inputStream = nil
        }

        if let outStream = outputStream {
            outStream.close()
            outStream.remove(from: .current, forMode: .common)
            outStream.delegate = nil
            outputStream = nil
        }

        writeBuffer.removeAll()
    }

    // MARK: - StreamDelegate

    public func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch eventCode {
        case .openCompleted:
            if isConnecting && inputStream?.streamStatus == .open && outputStream?.streamStatus == .open {
                isConnecting = false
                isConnected = true
                cancelTimeoutTimer()
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.networkSessionDidConnect(self)
                }
            }

        case .hasBytesAvailable:
            if let inStream = aStream as? InputStream {
                readFromStream(inStream)
            }

        case .hasSpaceAvailable:
            flushWriteBuffer()

        case .errorOccurred:
            let error = aStream.streamError ?? NSError(domain: "RFBNetworkSession", code: -2, userInfo: [NSLocalizedDescriptionKey: "Network stream error occurred"])
            handleError(error)

        case .endEncountered:
            disconnect()
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.networkSessionDidClose(self)
            }

        default:
            break
        }
    }

    private func readFromStream(_ stream: InputStream) {
        while stream.hasBytesAvailable {
            let bytesRead = stream.read(&readBuffer, maxLength: bufferSize)
            if bytesRead > 0 {
                let data = Data(readBuffer[0..<bytesRead])
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.delegate?.networkSession(self, didReceiveData: data)
                }
            } else if bytesRead < 0 {
                if let err = stream.streamError {
                    handleError(err)
                }
                break
            } else {
                // End of stream
                break
            }
        }
    }

    private func flushWriteBuffer() {
        guard let outStream = outputStream, outStream.hasSpaceAvailable, !writeBuffer.isEmpty else { return }

        writeBuffer.withUnsafeBytes { rawPtr in
            guard let ptr = rawPtr.bindMemory(to: UInt8.self).baseAddress else { return }
            let bytesWritten = outStream.write(ptr, maxLength: writeBuffer.count)
            if bytesWritten > 0 {
                writeBuffer.removeFirst(bytesWritten)
            } else if bytesWritten < 0 {
                if let err = outStream.streamError {
                    handleError(err)
                }
            }
        }
    }

    private func startTimeoutTimer() {
        cancelTimeoutTimer()
        let timer = DispatchSource.makeTimerSource(queue: networkQueue)
        timer.schedule(deadline: .now() + timeoutSeconds)
        timer.setEventHandler { [weak self] in
            guard let self = self, self.isConnecting else { return }
            self.handleError(NSError(domain: "RFBNetworkSession", code: -3, userInfo: [NSLocalizedDescriptionKey: "Connection timed out"]))
        }
        timer.resume()
        self.timeoutTimer = timer
    }

    private func cancelTimeoutTimer() {
        timeoutTimer?.cancel()
        timeoutTimer = nil
    }

    private func handleError(_ error: Error) {
        disconnect()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.networkSession(self, didFailWithError: error)
        }
    }
}
