import UIKit

internal class LoadingTableViewCell: UITableViewCell {
    
    @IBOutlet weak var activityIndicatorView: UIActivityIndicatorView!
    
    @IBOutlet weak var topLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var leftLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomLayoutConstraint: NSLayoutConstraint!
    @IBOutlet weak var rightLayoutConstraint: NSLayoutConstraint!
    
    internal var appearance = LoadingTableViewCellAppearance() {
        didSet {
            self.apply(appearance)
        }
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        self.apply(appearance)
    }
    
    internal func startAnimating() {
        self.activityIndicatorView.startAnimating()
    }
    
    internal func stopAnimating() {
        self.activityIndicatorView.stopAnimating()
        
    }
    
    internal func apply(_ appearance: LoadingTableViewCellAppearance) {
        self.activityIndicatorView.color = appearance.loaderTintColor
        
        self.topLayoutConstraint.constant = appearance.contentInset?.top ?? 0
        self.leftLayoutConstraint.constant = appearance.contentInset?.left ?? 0
        self.bottomLayoutConstraint.constant = appearance.contentInset?.bottom ?? 0
        self.rightLayoutConstraint.constant = appearance.contentInset?.right ?? 0
    }
}
