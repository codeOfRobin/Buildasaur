//
//  DashboardViewController.swift
//  Buildasaur
//
//  Created by Honza Dvorsky on 28/09/2015.
//  Copyright © 2015 Honza Dvorsky. All rights reserved.
//

import Cocoa
import BuildaKit
import ReactiveSwift
import Result

protocol EditeeDelegate: class, EmptyXcodeServerViewControllerDelegate, XcodeServerViewControllerDelegate, EmptyProjectViewControllerDelegate, ProjectViewControllerDelegate, EmptyBuildTemplateViewControllerDelegate, BuildTemplateViewControllerDelegate, SyncerViewControllerDelegate { }

class DashboardViewController: PresentableViewController {

    @IBOutlet weak var syncersTableView: NSTableView!
    @IBOutlet weak var startAllButton: NSButton!
    @IBOutlet weak var stopAllButton: NSButton!
    @IBOutlet weak var autostartButton: NSButton!
    @IBOutlet weak var launchOnLoginButton: NSButton!
    
    let config = MutableProperty<[String: AnyObject]>([:])
    
    //injected before viewDidLoad
    var syncerManager: SyncerManager!
    var serviceAuthenticator: ServiceAuthenticator!
    
    fileprivate var syncerViewModels: MutableProperty<[SyncerViewModel]> = MutableProperty([])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.configTitle()
        self.configDataSource()
        self.configTableView()
        self.configHeaderView()
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        
        if let window = self.view.window {
            window.minSize = CGSize(width: 700, height: 300)
        }
    }
    
    func configTitle() {
        let version = Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String
        self.title = "Buildasaur \(version), at your service!"
    }
    
    func configHeaderView() {
        
        //setup start/stop all buttons
        let anySyncerStateChanged = self.syncerViewModels.producer.flatMap(.merge) { newViewModels -> SignalProducer<SignalProducer<Bool, NoError>, NoError> in
            
            return SignalProducer { sink, _ in
                newViewModels.forEach { sink.send(value: $0.syncer.activeSignalProducer.producer) }
                sink.sendCompleted()
            }
        }.flatten(.merge)
        
        SignalProducer.combineLatest(anySyncerStateChanged, self.syncerViewModels.producer)
            .startWithValues { [weak self] (_, viewModels) -> () in
                guard let sself = self else { return }
                
                //startAll is enabled if >0 is NOT ACTIVE
                let startAllEnabled = viewModels.filter { !$0.syncer.active }.count > 0
                sself.startAllButton.isEnabled = startAllEnabled
                
                //stopAll is enabled if >0 is ACTIVE
                let stopAllEnabled = viewModels.filter { $0.syncer.active }.count > 0
                sself.stopAllButton.isEnabled = stopAllEnabled
        }
        
        //setup config
        self.config.value = self.syncerManager.storageManager.config.value
        self.autostartButton.on = self.config.value["autostart"] as? Bool ?? false
        
        self.config.producer.startWithValues { [weak self] config in
            guard let sself = self else { return }
            sself.syncerManager.storageManager.config.value = config
        }
        self.autostartButton.rac_on.startWithValues { [weak self] in
            guard let sself = self else { return }
            sself.config.value["autostart"] = $0 as AnyObject
        }
        
        //setup login item
        self.launchOnLoginButton.on = self.syncerManager.loginItem.isLaunchItem
    }
    
    func configTableView() {
        
        let tableView = self.syncersTableView
        tableView?.dataSource = self
        tableView?.delegate = self
        tableView?.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
    }
    
    func configDataSource() {
        
        let present: SyncerViewModel.PresentEditViewControllerType = {
            self.showSyncerEditViewControllerWithTriplet($0.toEditable(), state: .syncer)
        }
        self.syncerManager.syncersProducer.startWithValues { newSyncers in
            self.syncerViewModels.value = newSyncers
                .map { SyncerViewModel(syncer: $0, presentEditViewController: present) }
                .sorted { (o1, o2) in o1.initialProjectName < o2.initialProjectName }
            self.syncersTableView.reloadData()
        }
    }
    
    //MARK: Responding to button inside of cells
    
    fileprivate func syncerViewModelFromSender(_ sender: BuildaNSButton) -> SyncerViewModel {
        let selectedRow = sender.row!
        let syncerViewModel = self.syncerViewModels.value[selectedRow]
        return syncerViewModel
    }
    
    @IBAction func startAllButtonClicked(_ sender: AnyObject) {
        self.syncerViewModels.value.forEach { $0.startButtonClicked() }
    }
    
    @IBAction func stopAllButtonClicked(_ sender: AnyObject) {
        self.syncerViewModels.value.forEach { $0.stopButtonClicked() }
    }
    
    @IBAction func newSyncerButtonClicked(_ sender: AnyObject) {
        self.showNewSyncerViewController()
    }
    
    @IBAction func editButtonClicked(_ sender: BuildaNSButton) {
        self.syncerViewModelFromSender(sender).viewButtonClicked()
    }
    
    @IBAction func controlButtonClicked(_ sender: BuildaNSButton) {
        self.syncerViewModelFromSender(sender).controlButtonClicked()
    }
    
    @IBAction func doubleClickedRow(_ sender: AnyObject?) {
        let clickedRow = self.syncersTableView.clickedRow
        guard clickedRow >= 0 else { return }
        
        let syncerViewModel = self.syncerViewModels.value[clickedRow]
        syncerViewModel.viewButtonClicked()
    }
    
    @IBAction func infoButtonClicked(_ sender: AnyObject) {
        openLink("https://github.com/czechboy0/Buildasaur#buildasaur")
    }
    
    @IBAction func launchOnLoginClicked(_ sender: NSButton) {
        let newValue = sender.on
        let loginItem = self.syncerManager.loginItem
        loginItem.isLaunchItem = newValue
        
        //to be in sync in the UI, in case setting fails
        self.launchOnLoginButton.on = loginItem.isLaunchItem
    }
    
    @IBAction func checkForUpdatesClicked(_ sender: NSButton) {
        (NSApp.delegate as! AppDelegate).checkForUpdates(sender)
    }
}

extension DashboardViewController {
    
    func showNewSyncerViewController() {
        
        //configure an editing window with a brand new syncer
        let triplet = self.syncerManager.factory.newEditableTriplet()
        
//        //Debugging hack - insert the first server and project we have
//        triplet.server = self.syncerManager.storageManager.serverConfigs.value.first!.1
//        triplet.project = self.syncerManager.storageManager.projectConfigs.value["E94BAED5-7D91-426A-B6B6-5C39BF1F7032"]!
//        triplet.buildTemplate = self.syncerManager.storageManager.buildTemplates.value["EB0C3E74-C303-4C33-AF0E-012B650D2E9F"]
        
        self.showSyncerEditViewControllerWithTriplet(triplet, state: .noServer)
    }
    
    func showSyncerEditViewControllerWithTriplet(_ triplet: EditableConfigTriplet, state: EditorState) {
        
        let uniqueIdentifier = triplet.syncer.id
        let viewController: MainEditorViewController = self.storyboardLoader.presentableViewControllerWithStoryboardIdentifier("editorViewController", uniqueIdentifier: uniqueIdentifier, delegate: self.presentingDelegate)
        
        var context = EditorContext()
        context.configTriplet = triplet
        context.syncerManager = self.syncerManager
        viewController.factory = EditorViewControllerFactory(storyboardLoader: self.storyboardLoader, serviceAuthenticator: self.serviceAuthenticator)
        context.editeeDelegate = viewController
        viewController.context.value = context
        
        viewController.loadInState(state)

        self.presentingDelegate?.presentViewControllerInUniqueWindow(viewController)
    }
}

extension DashboardViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.syncerViewModels.value.count
    }
    
    enum Column: String {
        case Status = "status"
        case XCSHost = "xcs_host"
        case ProjectName = "project_name"
        case BuildTemplate = "build_template"
        case Control = "control"
        case Edit = "edit"
    }
    
    func getTypeOfReusableView<T: NSView>(_ column: Column) -> T {
        guard let view = self.syncersTableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: column.rawValue), owner: self) else {
            fatalError("Couldn't get a reusable view for column \(column)")
        }
        guard let typedView = view as? T else {
            fatalError("Couldn't type view \(view) into type \(T.className())")
        }
        return typedView
    }
    
    func bindTextView(_ view: NSTableCellView, column: Column, viewModel: SyncerViewModel) {
        
        let destination = view.textField!.rac_stringValue
        switch column {
        case .Status:
            destination <~ viewModel.status
        case .XCSHost:
            destination <~ viewModel.host
        case .ProjectName:
            destination <~ viewModel.projectName
        case .BuildTemplate:
            destination <~ viewModel.buildTemplateName
        default: break
        }
    }
    
    func bindButtonView(_ view: BuildaNSButton, column: Column, viewModel: SyncerViewModel) {
        
        let destinationTitle = view.rac_title
        let destinationEnabled = view.rac_enabled
        switch column {
        case .Edit:
            destinationTitle <~ viewModel.editButtonTitle
            destinationEnabled <~ viewModel.editButtonEnabled
        case .Control:
            destinationTitle <~ viewModel.controlButtonTitle
        default: break
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        guard let tcolumn = tableColumn else { return nil }
        let columnIdentifier = tcolumn.identifier
        guard let column = Column(rawValue: columnIdentifier.rawValue) else { return nil }
        let syncerViewModel = self.syncerViewModels.value[row]

        //based on the column decide which reuse identifier we'll use
        switch column {
        case .Status, .XCSHost, .ProjectName, .BuildTemplate:
            //basic text view
            let view: NSTableCellView = self.getTypeOfReusableView(column)
            self.bindTextView(view, column: column, viewModel: syncerViewModel)
            
            return view
            
        case .Control, .Edit:
            //push button
            let view: BuildaNSButton = self.getTypeOfReusableView(column)
            self.bindButtonView(view, column: column, viewModel: syncerViewModel)
            view.row = row
            return view
        }
    }
}

class BuildaNSButton: NSButton {
    var row: Int?
}

extension DashboardViewController: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 30
    }
}

