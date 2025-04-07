import UIKit
import Contacts
import ContactsUI
import Foundation
import MessageUI
import PhoneNumberKit

// 定义一个结构体来缓存联系人的相关信息
struct ContactCache {
    let pinyin: String
    let t9: String
    let phoneNumbers: [String]
}

extension String {
    func toPinyin() -> String {
        let mutableString = NSMutableString(string: self)
        CFStringTransform(mutableString, nil, kCFStringTransformToLatin, false)
        CFStringTransform(mutableString, nil, kCFStringTransformStripDiacritics, false)
        return mutableString as String
    }

    func pinyinToT9() -> String {
        let t9Mapping: [Character: String] = [
            "a": "2", "b": "2", "c": "2",
            "d": "3", "e": "3", "f": "3",
            "g": "4", "h": "4", "i": "4",
            "j": "5", "k": "5", "l": "5",
            "m": "6", "n": "6", "o": "6",
            "p": "7", "q": "7", "r": "7", "s": "7",
            "t": "8", "u": "8", "v": "8",
            "w": "9", "x": "9", "y": "9", "z": "9"
        ]
        var t9String = ""
        for char in self.lowercased() {
            if let digit = t9Mapping[char] {
                t9String.append(digit)
            }
        }
        return t9String
    }

    func removeFormattingCharacters() -> String {
        return self.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
    }
}

extension CNContactStore {
    func fetchContacts(matching request: CNContactFetchRequest) async throws -> [CNContact] {
        return try await withCheckedThrowingContinuation { continuation in
            var contacts: [CNContact] = []
            do {
                try self.enumerateContacts(with: request) { contact, _ in
                    contacts.append(contact)
                }
                continuation.resume(returning: contacts)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

class PaddingLabel: UILabel {
    var padding = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: padding.top, left: padding.left, bottom: padding.bottom, right: padding.right)
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        var contentSize = super.intrinsicContentSize
        contentSize.height += padding.top + padding.bottom
        contentSize.width += padding.left + padding.right
        return contentSize
    }
}

protocol ContactCellDelegate: AnyObject {
    func didTapName(contact: CNContact)
    func didTapPhoneNumber(phoneNumber: String, contact: CNContact)
    func contactForIndexPath(_ indexPath: IndexPath) -> CNContact?
}

class ContactCell: UITableViewCell {
    var phoneNumbers: [String] = [] {
        didSet {
            updatePhoneNumbers()
        }
    }

    weak var delegate: ContactCellDelegate?

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 8
        view.layer.borderColor = UIColor.lightGray.cgColor
        view.layer.borderWidth = 0.5
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    fileprivate let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .label
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let phoneNumberStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 4
        stackView.alignment = .trailing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.backgroundColor = .systemGroupedBackground
        setupViews()
        setupConstraints()
        setupGestures()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        contentView.addSubview(containerView)
        containerView.addSubview(nameLabel)
        containerView.addSubview(phoneNumberStackView)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 2),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -2),
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2)
        ])

        NSLayoutConstraint.activate([
            nameLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            nameLabel.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            nameLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),

            phoneNumberStackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 6),
            phoneNumberStackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -6),
            phoneNumberStackView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            phoneNumberStackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -6)
        ])
    }

    private func setupGestures() {
        let nameTapGesture = UITapGestureRecognizer(target: self, action: #selector(nameTapped))
        nameLabel.addGestureRecognizer(nameTapGesture)
        nameLabel.isUserInteractionEnabled = true
    }

    @objc private func nameTapped() {
        guard let tableView = superview as? UITableView,
              let indexPath = tableView.indexPath(for: self),
              let contact = delegate?.contactForIndexPath(indexPath) else { return }
        delegate?.didTapName(contact: contact)
    }

    private func updatePhoneNumbers() {
        phoneNumberStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        if phoneNumbers.isEmpty {
            phoneNumberStackView.isHidden = true
        } else {
            phoneNumberStackView.isHidden = false
            phoneNumbers.forEach { number in
                let phoneLabel = PaddingLabel()
                phoneLabel.text = number
                phoneLabel.font = .systemFont(ofSize: 16, weight: .semibold)
                phoneLabel.textColor = .systemBlue
                phoneLabel.isUserInteractionEnabled = true
                phoneLabel.layer.cornerRadius = 6
                phoneLabel.layer.borderColor = UIColor.systemBlue.cgColor
                phoneLabel.layer.borderWidth = 0.5
                phoneLabel.padding = UIEdgeInsets(top: 2, left: 6, bottom: 2, right: 6)

                let phoneTapGesture = UITapGestureRecognizer(target: self, action: #selector(phoneNumberTapped(_:)))
                phoneLabel.addGestureRecognizer(phoneTapGesture)
                phoneLabel.tag = phoneNumbers.firstIndex(of: number) ?? 0

                phoneNumberStackView.addArrangedSubview(phoneLabel)
            }
        }
    }

    @objc private func phoneNumberTapped(_ sender: UITapGestureRecognizer) {
        guard let phoneLabel = sender.view as? PaddingLabel,
              let tableView = superview as? UITableView,
              let indexPath = tableView.indexPath(for: self),
              let contact = delegate?.contactForIndexPath(indexPath),
              phoneNumbers.indices.contains(phoneLabel.tag) else { return }

        let cleanPhoneNumber = phoneNumbers[phoneLabel.tag].removeFormattingCharacters()
        delegate?.didTapPhoneNumber(phoneNumber: cleanPhoneNumber, contact: contact)
    }
}

class ViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UITableViewDataSource, UITableViewDelegate, ContactCellDelegate {

    // 定义键盘按钮的字符数组，将删除键放到最后，左下角放一个空按钮
    let keyboardCharacters = [
        ["1", ""],
        ["2", "abc"],
        ["3", "def"],
        ["4", "ghi"],
        ["5", "jkl"],
        ["6", "mno"],
        ["7", "pqrs"],
        ["8", "tuv"],
        ["9", "wxyz"],
        ["*", ""],
        ["0", "+"],
        ["#", ""],
        ["", ""], // 左下角空按钮
        ["Call", ""],
        ["⌫", ""]
    ]

    // 定义简化键盘按钮的字符数组，先初始化为空
    var simplifiedKeyboardCharacters: [[String]] = []

    // 定义联系人数组
    var contacts: [CNContact] = []
    var filteredContacts: [CNContact] = []

    // 缓存联系人的相关信息
    var contactCaches: [CNContact: ContactCache] = [:]

    // 定义输入的 T9 数字字符串
    var t9Input = ""

    // 定义集合视图（T9键盘）
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0 // 横向间距减少 10，这里设为 0
        layout.minimumLineSpacing = 0 // 纵向间距设为最小
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.backgroundColor = .systemBackground
        collectionView.showsVerticalScrollIndicator = false // 去掉纵向滚动条
        return collectionView
    }()

    // 定义简化集合视图（简化键盘）
    private lazy var simplifiedCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "simplifiedCell")
        collectionView.backgroundColor = .systemBackground
        collectionView.showsVerticalScrollIndicator = false
        return collectionView
    }()

    // 定义表格视图（联系人列表）
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ContactCell.self, forCellReuseIdentifier: "ContactCell")
        tableView.delegate = self
        return tableView
    }()

    // 定义显示输入 T9 数字的标签
    private lazy var inputLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 32) // 增大字体大小，确保显示清晰
        label.text = t9Input
        return label
    }()

    // 初始化 PhoneNumberKit 实例
    let phoneNumberKit = PhoneNumberUtility()

    // 标记是否显示简化键盘
    private var isSimplifiedKeyboardVisible = false

    // 用于调整 inputLabel 底部约束的变量
    private var inputLabelBottomConstraint: NSLayoutConstraint!

    override func viewDidLoad() {
        super.viewDidLoad()
        // 在这里初始化 simplifiedKeyboardCharacters
        simplifiedKeyboardCharacters = Array(keyboardCharacters[12...])
        setupUI()
        loadContacts()
        setupGestureRecognizers()
    }

    // 设置 UI 布局
    private func setupUI() {
        view.addSubview(collectionView)
        view.addSubview(simplifiedCollectionView)
        view.addSubview(tableView)
        view.addSubview(inputLabel)

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        simplifiedCollectionView.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        inputLabel.translatesAutoresizingMaskIntoConstraints = false

        let buttonWidth = (view.bounds.width - 40) / 3 - 20 // 恢复按钮原始宽度
        let buttonHeight = buttonWidth * 0.95 // 按钮高度
        let numberOfRows = (keyboardCharacters.count + 2) / 3 // 计算行数
        let collectionViewHeight = CGFloat(numberOfRows) * buttonHeight // collectionView 高度
        let simplifiedNumberOfRows = (simplifiedKeyboardCharacters.count + 2) / 3
        let simplifiedCollectionViewHeight = CGFloat(simplifiedNumberOfRows) * buttonHeight

        // 计算左右需要增加的间距，使按钮往中间聚拢
        let sideSpacing = (view.bounds.width - 40 - buttonWidth * 3) / 2

        inputLabelBottomConstraint = inputLabel.bottomAnchor.constraint(equalTo: collectionView.topAnchor, constant: -10)

        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputLabel.topAnchor, constant: -20),

            inputLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            inputLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            inputLabelBottomConstraint,
            inputLabel.heightAnchor.constraint(equalToConstant: 30), // 增加高度，确保有足够空间显示

            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20 + sideSpacing),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20 - sideSpacing),
            collectionView.heightAnchor.constraint(equalToConstant: collectionViewHeight),
            // 修改 collectionView 底部约束
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30 + buttonHeight),

            simplifiedCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20 + sideSpacing),
            simplifiedCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20 - sideSpacing),
            simplifiedCollectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 10),
            simplifiedCollectionView.heightAnchor.constraint(equalToConstant: simplifiedCollectionViewHeight)
        ])

        simplifiedCollectionView.isHidden = true
    }

    // 加载联系人
    private func loadContacts() {
        let store = CNContactStore()
        let stringKeys: [String] = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey]
        let stringKeyDescriptors = stringKeys.map { $0 as CNKeyDescriptor }
        let keysToFetch = stringKeyDescriptors + [CNContactViewController.descriptorForRequiredKeys()]
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)

        Task {
            do {
                let fetchedContacts = try await store.fetchContacts(matching: request)
                contacts = fetchedContacts.sorted { $0.givenName + $0.familyName < $1.givenName + $1.familyName }
                // 缓存联系人信息
                contactCaches = contacts.reduce(into: [:]) { cache, contact in
                    let givenPinyin = contact.givenName.toPinyin()
                    let familyPinyin = contact.familyName.toPinyin()
                    let pinyin = givenPinyin + familyPinyin
                    let t9 = pinyin.pinyinToT9()
                    let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue.removeFormattingCharacters() }
                    cache[contact] = ContactCache(pinyin: pinyin, t9: t9, phoneNumbers: phoneNumbers)
                }
                filteredContacts = contacts
                tableView.reloadData()
            } catch {
                print("Error fetching contacts: \(error)")
            }
        }
    }

    // 搜索联系人
    private func searchContacts() {
        let input = t9Input
        if input.isEmpty {
            filteredContacts = contacts
        } else {
            filteredContacts = contacts.filter { contact in
                guard let cache = contactCaches[contact] else { return false }
                return cache.t9.contains(input) ||
                    cache.pinyin.pinyinToT9().contains(input) ||
                    cache.phoneNumbers.contains { $0.contains(input) }
            }
        }
        tableView.reloadData()
        inputLabel.text = t9Input
        // 更新删除按钮的显示状态
        collectionView.reloadItems(at: [IndexPath(item: keyboardCharacters.count - 1, section: 0)])
        simplifiedCollectionView.reloadItems(at: [IndexPath(item: simplifiedKeyboardCharacters.count - 1, section: 0)])
    }

    // 处理键盘按钮点击事件
    private func handleButtonTap(_ character: String) {
        if character == "⌫" {
            if (t9Input.isEmpty == false) {
                t9Input.removeLast()
            }
        } else if character == "Call" {
            let phoneNumber = inputLabel.text?.removeFormattingCharacters()
            if let phoneNumber = phoneNumber, !phoneNumber.isEmpty {
                if let url = URL(string: "tel://\(phoneNumber)"), UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            }
        } else if let digit = Int(String(character.first ?? Character(""))) {
            t9Input.append("\(digit)")
        }
        searchContacts()
    }

    // UICollectionViewDataSource 方法
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == self.collectionView {
            return keyboardCharacters.count
        } else {
            return simplifiedKeyboardCharacters.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let reuseIdentifier = collectionView == self.collectionView ? "cell" : "simplifiedCell"
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: reuseIdentifier, for: indexPath)

        let button = UIButton(frame: CGRect(x: 0, y: 0, width: cell.bounds.width * 0.95, height: cell.bounds.height * 0.95))
        button.center = cell.contentView.center

        let characters = collectionView == self.collectionView ? keyboardCharacters : simplifiedKeyboardCharacters
        let mainChar = characters[indexPath.item][0]
        let subChar = characters[indexPath.item][1].uppercased() // 使用大写字母

        if (mainChar.isEmpty == true) {
            button.isHidden = true // 隐藏左下角按钮
        } else if mainChar == "⌫" {
            // 根据 t9Input 的状态控制删除按钮的显示与隐藏
            button.isHidden = t9Input.isEmpty
        }

        if (button.isHidden == false) {
            if mainChar == "Call" {
                // 使用系统打电话图标
                let callImage = UIImage(systemName: "phone.fill")
                button.setImage(callImage, for: .normal)
                button.tintColor = .systemGreen
            } else {
                let digitFontSize = 14 + 10 // 数字比字母大 10 个字号
                let attributedString = NSMutableAttributedString(string: mainChar, attributes: [.font: UIFont.systemFont(ofSize: CGFloat(digitFontSize))])
                if (subChar.isEmpty == false) {
                    attributedString.append(NSAttributedString(string: "\n\(subChar)", attributes: [
                        .font: UIFont.systemFont(ofSize: 14),
                        .paragraphStyle: {
                            let paragraphStyle = NSMutableParagraphStyle()
                            paragraphStyle.lineBreakMode = .byWordWrapping
                            paragraphStyle.alignment = .center
                            return paragraphStyle
                        }()
                    ]))
                }
                button.setAttributedTitle(attributedString, for: .normal)
                button.titleLabel?.numberOfLines = 0 // 允许多行显示
                button.titleLabel?.textAlignment = .center // 确保文本居中显示
                button.setTitleColor(.label, for: .normal)
            }
            button.backgroundColor = .systemGray5
            button.layer.cornerRadius = button.bounds.width / 2
            button.isUserInteractionEnabled = true // 确保按钮可交互
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
        }

        cell.contentView.addSubview(button)
        return cell
    }

    // UICollectionViewDelegateFlowLayout 方法
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == self.collectionView {
            // 恢复按钮原始宽度
            let width = (collectionView.bounds.width) / 3 - 20
            return CGSize(width: width, height: width)
        } else {
            let width = (collectionView.bounds.width) / 3 - 20
            return CGSize(width: width, height: width)
        }
    }

    // 处理按钮点击事件
    @objc private func buttonTapped(_ sender: UIButton) {
        if let attributedTitle = sender.attributedTitle(for: .normal) {
            let mutableAttributedTitle = NSMutableAttributedString(attributedString: attributedTitle)
            // 移除换行符及后面的内容，只保留主字符
            if let range = mutableAttributedTitle.string.range(of: "\n") {
                mutableAttributedTitle.deleteCharacters(in: NSRange(range.lowerBound..., in: mutableAttributedTitle.string))
            }
            let title = mutableAttributedTitle.string
            handleButtonTap(title)
        } else if sender.image(for: .normal) != nil {
            handleButtonTap("Call")
        }
    }

    // UITableViewDataSource 方法
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredContacts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ContactCell", for: indexPath) as! ContactCell
        let contact = filteredContacts[indexPath.row]
        cell.nameLabel.text = "\(contact.givenName) \(contact.familyName)"
        cell.phoneNumbers = contact.phoneNumbers.compactMap { labeledValue in
            let phoneNumberString = labeledValue.value.stringValue
            let label = labeledValue.label.map { CNLabeledValue<CNPhoneNumber>.localizedString(forLabel: $0) } ?? ""
            do {
                let phoneNumber = try phoneNumberKit.parse(phoneNumberString)
                let formattedNumber = phoneNumberKit.format(phoneNumber, toType: .international)
                return "\(formattedNumber) (\(label))"
            } catch {
                return "\(phoneNumberString) (\(label))"
            }
        }
        cell.delegate = self
        return cell
    }

    // UITableViewDelegate 方法
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let contact = filteredContacts[indexPath.row]
        let contactViewController = CNContactViewController(for: contact)
        contactViewController.allowsActions = true
        contactViewController.displayedPropertyKeys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey]
        contactViewController.delegate = self // 设置代理
        // 添加取消按钮
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTapped))
        contactViewController.navigationItem.leftBarButtonItem = cancelButton
        let navigationController = UINavigationController(rootViewController: contactViewController)
        present(navigationController, animated: true, completion: nil)
    }

    // ContactCellDelegate 方法
    func didTapName(contact: CNContact) {
        let contactViewController = CNContactViewController(for: contact)
        contactViewController.allowsActions = true
        contactViewController.displayedPropertyKeys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey]
        contactViewController.delegate = self // 设置代理
        // 添加取消按钮
        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonTapped))
        contactViewController.navigationItem.leftBarButtonItem = cancelButton
        let navigationController = UINavigationController(rootViewController: contactViewController)
        present(navigationController, animated: true, completion: nil)
    }

    func didTapPhoneNumber(phoneNumber: String, contact: CNContact) {
        let cleanPhoneNumber = phoneNumber.removeFormattingCharacters()
        if let url = URL(string: "tel://\(cleanPhoneNumber)"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    func contactForIndexPath(_ indexPath: IndexPath) -> CNContact? {
        return filteredContacts[safe: indexPath.row]
    }

    // 取消按钮点击事件处理
    @objc private func cancelButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    // 设置手势识别器
    private func setupGestureRecognizers() {
        let swipeDownGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeDownGesture))
        swipeDownGesture.direction = .down
        collectionView.addGestureRecognizer(swipeDownGesture)

        let swipeUpGesture = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeUpGesture))
        swipeUpGesture.direction = .up
        simplifiedCollectionView.addGestureRecognizer(swipeUpGesture)
    }

    // 处理向下滑动手势
    @objc private func handleSwipeDownGesture() {
        showSimplifiedKeyboard()
    }

    // 显示简化键盘
    private func showSimplifiedKeyboard() {
        isSimplifiedKeyboardVisible = true
        collectionView.isHidden = true
        collectionView.alpha = 0 // 确保完全隐藏
        simplifiedCollectionView.isHidden = false
        simplifiedCollectionView.alpha = 1 // 确保完全显示

        let buttonWidth = (view.bounds.width - 40) / 3 - 20 // 恢复按钮原始宽度
        let buttonHeight = buttonWidth * 0.95 // 按钮高度
        let rowsToRemove = 3 // 根据实际情况调整
        let heightToMoveDown = CGFloat(rowsToRemove) * buttonHeight

        // 调整 inputLabel 底部约束，确保不会出现布局冲突
//        let minConstant = -10 // 最小约束值
//        let newConstant = -heightToMoveDown - 10
        inputLabelBottomConstraint.constant = heightToMoveDown+20//max(newConstant, CGFloat(minConstant))

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    // 显示完整 T9 键盘
    private func showFullKeyboard() {
        isSimplifiedKeyboardVisible = false
        collectionView.isHidden = false
        collectionView.alpha = 1 // 确保完全显示
        simplifiedCollectionView.isHidden = true
        simplifiedCollectionView.alpha = 0 // 确保完全隐藏

        // 恢复 inputLabel 底部约束
        inputLabelBottomConstraint.constant = -10

        UIView.animate(withDuration: 0.3) {
            self.view.layoutIfNeeded()
        }
    }

    // 处理向上滑动手势
    @objc private func handleSwipeUpGesture() {
        showFullKeyboard()
    }
}

// 实现 CNContactViewControllerDelegate 协议
extension ViewController: CNContactViewControllerDelegate {
    func contactViewController(_ viewController: CNContactViewController, didCompleteWith contact: CNContact?) {
        // 关闭联系人信息界面
        viewController.navigationController?.dismiss(animated: true, completion: nil)
    }
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
