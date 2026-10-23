import UIKit

public protocol InputHandlerDelegate: AnyObject {
    func inputHandler(_ handler: InputHandler, sendPointerEvent buttonMask: UInt8, x: UInt16, y: UInt16)
}

/// Gesture recognition and pointer event translation (Section 9, Phase Five).
public final class InputHandler: NSObject, UIGestureRecognizerDelegate {

    public weak var delegate: InputHandlerDelegate?
    private weak var targetView: FramebufferView?

    private var tapGesture: UITapGestureRecognizer!
    private var panGesture: UIPanGestureRecognizer!
    private var longPressGesture: UILongPressGestureRecognizer!
    private var twoFingerPanGesture: UIPanGestureRecognizer!

    private var currentButtonMask: UInt8 = 0
    private var lastPointerX: UInt16 = 0
    private var lastPointerY: UInt16 = 0

    public init(targetView: FramebufferView) {
        self.targetView = targetView
        super.init()
        setupGestures(on: targetView)
    }

    private func setupGestures(on view: UIView) {
        view.isUserInteractionEnabled = true

        // 1. Single tap = left click
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        tapGesture.numberOfTapsRequired = 1
        tapGesture.numberOfTouchesRequired = 1
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)

        // 2. Pan = left drag / pointer movement
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.maximumNumberOfTouches = 1
        panGesture.delegate = self
        view.addGestureRecognizer(panGesture)

        // 3. Long press = right click
        longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.5
        longPressGesture.delegate = self
        view.addGestureRecognizer(longPressGesture)

        // 4. Two finger pan = vertical/horizontal scroll
        twoFingerPanGesture = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPanGesture.minimumNumberOfTouches = 2
        twoFingerPanGesture.maximumNumberOfTouches = 2
        twoFingerPanGesture.delegate = self
        view.addGestureRecognizer(twoFingerPanGesture)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let view = targetView else { return }
        let location = gesture.location(in: view)
        guard let fbPoint = view.convertPointToFramebuffer(location) else { return }

        let x = UInt16(fbPoint.x)
        let y = UInt16(fbPoint.y)

        // Press left button (1) then release (0)
        delegate?.inputHandler(self, sendPointerEvent: 1, x: x, y: y)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self = self else { return }
            self.delegate?.inputHandler(self, sendPointerEvent: 0, x: x, y: y)
        }
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = targetView else { return }
        let location = gesture.location(in: view)
        guard let fbPoint = view.convertPointToFramebuffer(location) else { return }

        let x = UInt16(fbPoint.x)
        let y = UInt16(fbPoint.y)
        lastPointerX = x
        lastPointerY = y

        switch gesture.state {
        case .began:
            currentButtonMask = 1 // Left button down
            delegate?.inputHandler(self, sendPointerEvent: currentButtonMask, x: x, y: y)
        case .changed:
            delegate?.inputHandler(self, sendPointerEvent: currentButtonMask, x: x, y: y)
        case .ended, .cancelled, .failed:
            currentButtonMask = 0 // Button released
            delegate?.inputHandler(self, sendPointerEvent: 0, x: x, y: y)
        default:
            break
        }
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let view = targetView else { return }
        let location = gesture.location(in: view)
        guard let fbPoint = view.convertPointToFramebuffer(location) else { return }

        let x = UInt16(fbPoint.x)
        let y = UInt16(fbPoint.y)

        if gesture.state == .began {
            // Right click (button mask = 4)
            delegate?.inputHandler(self, sendPointerEvent: 4, x: x, y: y)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self = self else { return }
                self.delegate?.inputHandler(self, sendPointerEvent: 0, x: x, y: y)
            }
        }
    }

    @objc private func handleTwoFingerPan(_ gesture: UIPanGestureRecognizer) {
        guard let view = targetView else { return }
        let velocity = gesture.velocity(in: view)
        let location = gesture.location(in: view)
        guard let fbPoint = view.convertPointToFramebuffer(location) else { return }

        let x = UInt16(fbPoint.x)
        let y = UInt16(fbPoint.y)

        // RFB mouse scroll: button 8 (wheel up) and 16 (wheel down)
        if abs(velocity.y) > 100 {
            let mask: UInt8 = velocity.y > 0 ? 16 : 8 // 16 = scroll down, 8 = scroll up
            delegate?.inputHandler(self, sendPointerEvent: mask, x: x, y: y)
            delegate?.inputHandler(self, sendPointerEvent: 0, x: x, y: y)
        }
    }

    /// Releases any held pointer buttons on disconnect or backgrounding.
    public func releaseAllButtons() {
        if currentButtonMask != 0 {
            currentButtonMask = 0
            delegate?.inputHandler(self, sendPointerEvent: 0, x: lastPointerX, y: lastPointerY)
        }
    }

    // MARK: - UIGestureRecognizerDelegate

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return false
    }
}
