import UIKit

final class MessageImageViewController: UIViewController {

    private var scrollView = UIScrollView()
    private var imageView = UIImageView()
    private var activityIndicatorView = UIActivityIndicatorView()

    var message: Message?

    private let messageRepository: MessageRepositoryProtocol
    private let imageLoader: ImageLoaderProtocol

    init(messageRepository: MessageRepositoryProtocol, imageLoader: ImageLoaderProtocol = Parley.shared.imageLoader) {
        self.messageRepository = messageRepository
        self.imageLoader = imageLoader

        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupView()
        setupScrollView()
        setupImageView()
        setupActivityIndicatorView()

        addSwipeToDismissPanGestureRecognizer()

        addDismissButton()
    }
    
    private func updateScale() {
        let widthScale = 1 / self.imageView.frame.width * self.scrollView.bounds.width
        let heightScale = 1 / self.imageView.frame.height * self.scrollView.bounds.height
        
        let minimumScale = min(widthScale, heightScale)
        if minimumScale < 1 {
            scrollView.minimumZoomScale = minimumScale
            scrollView.zoomScale = minimumScale
        }
        scrollView.maximumZoomScale = minimumScale * 3

        adjustContentInset()
    }

    private func setupView() {
        view.backgroundColor = UIColor(white: 0.0, alpha: 0.75)
    }

    private func setupScrollView() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

        scrollView.delegate = self
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            NSLayoutConstraint(
                item: scrollView,
                attribute: .top,
                relatedBy: .equal,
                toItem: view,
                attribute: .top,
                multiplier: 1,
                constant: 0
            ),
            NSLayoutConstraint(
                item: scrollView,
                attribute: .trailing,
                relatedBy: .equal,
                toItem: view,
                attribute: .trailing,
                multiplier: 1,
                constant: 0
            ),
            NSLayoutConstraint(
                item: scrollView,
                attribute: .bottom,
                relatedBy: .equal,
                toItem: view,
                attribute: .bottom,
                multiplier: 1,
                constant: 0
            ),
            NSLayoutConstraint(
                item: scrollView,
                attribute: .leading,
                relatedBy: .equal,
                toItem: view,
                attribute: .leading,
                multiplier: 1,
                constant: 0
            ),
        ])
    }

    private func setupImageView() {
        scrollView.addSubview(imageView)
        guard let mediaId = message?.media?.id else {
            dismiss(animated: true, completion: nil) ; return
        }

        displayImageLoading()
        loadImage(id: mediaId)
    }

    private func displayImageLoading() {
        activityIndicatorView.startAnimating()
    }

    private func loadImage(id: String) {
        Task {
            do {
                let image = try await imageLoader.load(id: id)
                display(image: image.image)
            } catch {
                displayFailedLoadingImage()
            }
        }
    }

    @MainActor
    private func display(image: UIImage) {
        imageView.image = image
        imageView.sizeToFit()
        updateScale()
        activityIndicatorView.stopAnimating()
    }

    @MainActor
    private func displayFailedLoadingImage() {
        dismiss(animated: true, completion: nil)
    }

    private func setupActivityIndicatorView() {
        activityIndicatorView.style = .medium
        activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(activityIndicatorView)

        NSLayoutConstraint(
            item: activityIndicatorView,
            attribute: .centerX,
            relatedBy: .equal,
            toItem: view,
            attribute: .centerX,
            multiplier: 1,
            constant: 0
        ).isActive = true
        NSLayoutConstraint(
            item: activityIndicatorView,
            attribute: .centerY,
            relatedBy: .equal,
            toItem: view,
            attribute: .centerY,
            multiplier: 1,
            constant: 0
        ).isActive = true
    }

    private func adjustContentInset() {
        let imageViewSize = imageView.frame.size
        let scrollViewSize = scrollView.bounds.size

        let verticalInset = imageViewSize.height < scrollViewSize
            .height ? (scrollViewSize.height - imageViewSize.height) / 2 : 0
        let horizontalInset = imageViewSize.width < scrollViewSize
            .width ? (scrollViewSize.width - imageViewSize.width) / 2 : 0
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }
    
    private func addDismissButton() {
        let button = UIButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        let image = UIImage(named: "ic_close", in: .module, compatibleWith: .none)?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.isAccessibilityElement = true
        button.accessibilityLabel = "parley_close".localized

        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])

        button.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
    }

    @objc
    private func dismissTapped() {
        dismissWithSwipeToDismiss(1)
    }

    // MARK: Swipe to dismiss
    private func addSwipeToDismissPanGestureRecognizer() {
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleSwipeToDismiss))
        panGestureRecognizer.cancelsTouchesInView = false

        view.addGestureRecognizer(panGestureRecognizer)
    }

    @objc
    func handleSwipeToDismiss(_ panGestureRecognizer: UIPanGestureRecognizer) {
        let translation = panGestureRecognizer.translation(in: view)
        let translationY = translation.y
        let translationYAbsolute = abs(translationY)

        var frame = scrollView.frame
        frame.origin = CGPoint(x: 0, y: translationY)
        scrollView.frame = frame

        view.alpha = 1 - (translationYAbsolute / 300)

        if panGestureRecognizer.state == .ended {
            if translationYAbsolute > 100 {
                dismissWithSwipeToDismiss(translationY)
            } else {
                resetSwipeToDismiss()
            }
        }
    }

    private func dismissWithSwipeToDismiss(_ translationY: CGFloat) {
        UIView.animate(withDuration: 0.25, animations: {
            self.view.alpha = 0

            var frame = self.scrollView.frame
            frame.origin = CGPoint(x: 0, y: translationY > 0 ? self.view.frame.height : -self.view.frame.height)
            self.scrollView.frame = frame
        }) { _ in
            self.dismiss(animated: false, completion: nil)
        }
    }

    private func resetSwipeToDismiss() {
        UIView.animate(withDuration: 0.25) {
            self.view.alpha = 1

            var frame = self.scrollView.frame
            frame.origin = CGPoint(x: 0, y: 0)
            self.scrollView.frame = frame
        }
    }
}

extension MessageImageViewController: UIScrollViewDelegate {

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        adjustContentInset()
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }
}
