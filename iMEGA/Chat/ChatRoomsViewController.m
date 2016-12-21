#import "ChatRoomsViewController.h"

#import "MEGASdkManager.h"
#import "ChatRoomCell.h"
#import "MessagesViewController.h"
#import "ContactsViewController.h"
#import "MEGANavigationController.h"
#import "ContactDetailsViewController.h"
#import "MEGAReachabilityManager.h"
#import "GroupChatDetailsViewController.h"

#import "DateTools.h"
#import "UIImage+GKContact.h"
#import "UIScrollView+EmptyDataSet.h"

#import "Helper.h"
#import "UIImageView+MNZCategory.h"
#import "NSMutableAttributedString+MNZCategory.h"

@interface ChatRoomsViewController () <UITableViewDataSource, UITableViewDelegate, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, MEGAChatRequestDelegate, MEGAChatDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *addBarButtonItem;

@property (nonatomic, strong) MEGAChatListItemList *chatListItemList;
@property (nonatomic, strong) NSArray *chatListItemArray;
@property (nonatomic, strong) NSMutableDictionary *chatListItemIndexPathDictionary;

@end

@implementation ChatRoomsViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    self.tableView.emptyDataSetSource = self;
    self.tableView.emptyDataSetDelegate = self;
    
    self.title = AMLocalizedString(@"Chat", nil);
    self.chatListItemIndexPathDictionary = [[NSMutableDictionary alloc] init];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(internetConnectionChanged) name:kReachabilityChangedNotification object:nil];
    
    self.tabBarController.tabBar.hidden = NO;
    [[MEGASdkManager sharedMEGAChatSdk] addChatDelegate:self];
    
    [self sortChatListItems];
    
    [self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kReachabilityChangedNotification object:nil];
    
    [[MEGASdkManager sharedMEGAChatSdk] removeChatDelegate:self];
}



#pragma mark - DZNEmptyDataSetSource

- (NSAttributedString *)titleForEmptyDataSet:(UIScrollView *)scrollView {
    [self.tableView setSeparatorStyle:UITableViewCellSeparatorStyleNone];
    NSString *text;
    if ([MEGAReachabilityManager isReachable]) {
        return [NSMutableAttributedString mnz_darkenSectionTitleInString:@"No Conversations" sectionTitle:@"Conversations"];
    } else {
        text = AMLocalizedString(@"noInternetConnection",  @"No Internet Connection");
    }
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont fontWithName:@"SFUIText-Light" size:18.0], NSForegroundColorAttributeName:[UIColor mnz_gray999999]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}


- (UIImage *)imageForEmptyDataSet:(UIScrollView *)scrollView {
    if ([MEGAReachabilityManager isReachable]) {
        // TODO: We need change this image with a custom image provided by design team
        return [UIImage imageNamed:@"emptyContacts"];
    } else {
        return [UIImage imageNamed:@"noInternetConnection"];
    }
}

- (NSAttributedString *)buttonTitleForEmptyDataSet:(UIScrollView *)scrollView forState:(UIControlState)state {
    NSString *text = @"";
    if ([MEGAReachabilityManager isReachable]) {
        text = @"Invite";
    }
    
    NSDictionary *attributes = @{NSFontAttributeName:[UIFont fontWithName:@"SFUIText-Light" size:20.0f], NSForegroundColorAttributeName:[UIColor mnz_gray777777]};
    
    return [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

- (UIImage *)buttonBackgroundImageForEmptyDataSet:(UIScrollView *)scrollView forState:(UIControlState)state {
    UIEdgeInsets capInsets = [Helper capInsetsForEmptyStateButton];
    UIEdgeInsets rectInsets = [Helper rectInsetsForEmptyStateButton];
    
    return [[[UIImage imageNamed:@"buttonBorder"] resizableImageWithCapInsets:capInsets resizingMode:UIImageResizingModeStretch] imageWithAlignmentRectInsets:rectInsets];
}

- (UIColor *)backgroundColorForEmptyDataSet:(UIScrollView *)scrollView {
    return [UIColor whiteColor];
}

- (CGFloat)verticalOffsetForEmptyDataSet:(UIScrollView *)scrollView {
    return [Helper verticalOffsetForEmptyStateWithNavigationBarSize:self.navigationController.navigationBar.frame.size searchBarActive:[self.searchDisplayController isActive]];
}

- (CGFloat)spaceHeightForEmptyDataSet:(UIScrollView *)scrollView {
    return [Helper spaceHeightForEmptyState];
}

#pragma mark - DZNEmptyDataSetDelegate Methods

- (void)emptyDataSet:(UIScrollView *)scrollView didTapButton:(UIButton *)button {
    [self addTapped:(UIBarButtonItem *)button];
}

#pragma mark - Private

- (void)internetConnectionChanged {
    BOOL boolValue = [MEGAReachabilityManager isReachable];
    self.addBarButtonItem.enabled = boolValue;
    
    [self.tableView reloadData];
}

- (void)sortChatListItems {
    self.chatListItemList = [[MEGASdkManager sharedMEGAChatSdk] chatListItems];
    
    NSMutableArray *tempArray = [[NSMutableArray alloc] initWithCapacity:self.chatListItemList.size];
    for (NSUInteger i = 0; i < self.chatListItemList.size ; i++) {
        [tempArray addObject:[self.chatListItemList chatListItemAtIndex:i]];
    }
    
    
    self.chatListItemArray = [tempArray sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSDate *first  = [[(MEGAChatListItem *)a lastMessage] timestamp];
        NSDate *second = [[(MEGAChatListItem *)b lastMessage] timestamp];
        
        if (!first) {
            first = [NSDate dateWithTimeIntervalSince1970:0];
        }
        if (!second) {
            second = [NSDate dateWithTimeIntervalSince1970:0];
        }
        
        return [second compare:first];
    }];
    
    NSInteger i = 0;
    for (MEGAChatListItem *item in self.chatListItemArray) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        [self.chatListItemIndexPathDictionary setObject:indexPath forKey:@(item.chatId)];
        i++;
    }
}

#pragma mark - IBActions

- (IBAction)addTapped:(UIBarButtonItem *)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self dismissViewControllerAnimated:YES completion:^{
        }];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"Start conversation", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        
        MEGANavigationController *navigationController = [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactsNavigationControllerID"];
        ContactsViewController *contactsVC = navigationController.viewControllers.firstObject;
        contactsVC.contactsMode = ContactsChatStartConversation;
        contactsVC.userSelected =^void(NSArray *users) {
            if (users.count == 1) {
                MEGAUser *user = [users objectAtIndex:0];
                MEGAChatRoom *chatRoom = [[MEGASdkManager sharedMEGAChatSdk] chatRoomByUser:user.handle];
                if (chatRoom) {
                    MEGALogInfo(@"%@", chatRoom);
                    NSInteger i = 0;
                    for (i = 0; i < self.chatListItemArray.count; i++){
                        if (chatRoom.chatId == [[self.chatListItemArray objectAtIndex:i] chatId]) {
                            break;
                        }
                    }
                    
                    MessagesViewController *messagesVC = [[MessagesViewController alloc] init];
                    messagesVC.chatRoom                = chatRoom;
                    dispatch_async(dispatch_get_main_queue(), ^(void){
                        [self.navigationController pushViewController:messagesVC animated:YES];
                    });
                } else {
                    MEGAChatPeerList *peerList = [[MEGAChatPeerList alloc] init];
                    [peerList addPeerWithHandle:user.handle privilege:2];
                    
                    [[MEGASdkManager sharedMEGAChatSdk] createChatGroup:NO peers:peerList delegate:self];
                }
            } else {
                MEGAChatPeerList *peerList = [[MEGAChatPeerList alloc] init];
                
                for (NSInteger i = 0; i < users.count; i++) {
                    MEGAUser *user = [users objectAtIndex:i];
                    [peerList addPeerWithHandle:user.handle privilege:2];
                }
                
                [[MEGASdkManager sharedMEGAChatSdk] createChatGroup:YES peers:peerList delegate:self];
            }
        };
        
        [self presentViewController:navigationController animated:YES completion:nil];
        
    }]];
    
    if ([[UIDevice currentDevice] iPadDevice]) {
        alertController.modalPresentationStyle = UIModalPresentationPopover;
        UIPopoverPresentationController *popoverPresentationController = [alertController popoverPresentationController];
        popoverPresentationController.barButtonItem = self.addBarButtonItem;
        popoverPresentationController.sourceView = self.view;
    }
    [self presentViewController:alertController animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.chatListItemArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ChatRoomCell *cell = [tableView dequeueReusableCellWithIdentifier:@"chatRoomCell" forIndexPath:indexPath];
    
    MEGAChatListItem *chatListItem = [self.chatListItemArray objectAtIndex:indexPath.row];
    MEGALogInfo(@"%@", chatListItem);
    
    cell.chatTitle.text = chatListItem.title;
    
    if (chatListItem.lastMessage.isManagementMessage) {
        cell.chatLastMessage.text = @"Management message";
    } else {
        cell.chatLastMessage.text = chatListItem.lastMessage.content;
    }
    cell.chatLastTime.text = chatListItem.lastMessage.timestamp.shortTimeAgoSinceNow;
    if (chatListItem.isGroup) {
        cell.onlineStatusView.hidden = YES;
        UIImage *avatar = [UIImage imageForName:chatListItem.title.uppercaseString size:cell.avatarImageView.frame.size backgroundColor:[UIColor mnz_gray999999] textColor:[UIColor whiteColor] font:[UIFont fontWithName:@"SFUIText-Light" size:(cell.avatarImageView.frame.size.width/2)]];
        
        cell.avatarImageView.image = avatar;
    } else {
        [cell.avatarImageView mnz_setImageForUserHandle:chatListItem.peerHandle];
        if (chatListItem.onlineStatus == 0) {
            cell.onlineStatusView.backgroundColor = [UIColor mnz_gray666666];
        } else if (chatListItem.onlineStatus == 3) {
            cell.onlineStatusView.backgroundColor = [UIColor mnz_green13E03C];
        }
        cell.onlineStatusView.hidden             = NO;
        cell.onlineStatusView.layer.cornerRadius = cell.onlineStatusView.frame.size.width / 2;
    }
    
    if (chatListItem.unreadCount != 0) {
        cell.unreadCount.hidden             = NO;
        cell.unreadCount.layer.cornerRadius = 6.0f;
        cell.unreadCount.clipsToBounds      = YES;
        cell.unreadCount.text               = [NSString stringWithFormat:@"%ld", (long)chatListItem.unreadCount];
    } else {
        cell.unreadCount.hidden = YES;
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGAChatListItem *chatListItem = [self.chatListItemArray objectAtIndex:indexPath.row];
    MEGAChatRoom *chatRoom         = [[MEGASdkManager sharedMEGAChatSdk] chatRoomForChatId:chatListItem.chatId];
    
    MessagesViewController *messagesVC = [[MessagesViewController alloc] init];
    messagesVC.chatRoom                = chatRoom;
    
    [self.navigationController pushViewController:messagesVC animated:YES];
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    MEGAChatListItem *chatListItem = [self.chatListItemArray objectAtIndex:indexPath.row];
    
    UITableViewRowAction *moreAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDefault title:AMLocalizedString(@"More", nil) handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        
        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
            [self dismissViewControllerAnimated:YES completion:nil];
            [self.tableView setEditing:NO];
        }]];
        
        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"Mute", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"TODO" message:@"Not implemented yet" preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleCancel handler:nil]];
            [self presentViewController:alertController animated:YES completion:nil];
        }]];
        
        [alertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"Info", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            if (chatListItem.isGroup) {
                GroupChatDetailsViewController *groupChatDetailsVC = [[UIStoryboard storyboardWithName:@"Chat" bundle:nil] instantiateViewControllerWithIdentifier:@"GroupChatDetailsViewControllerID"];
                MEGAChatRoom *chatRoom = [[MEGASdkManager sharedMEGAChatSdk] chatRoomForChatId:chatListItem.chatId];
                groupChatDetailsVC.chatRoom = chatRoom;
                
                [self.navigationController pushViewController:groupChatDetailsVC animated:YES];
            } else {
                MEGAChatRoom *chatRoom = [[MEGASdkManager sharedMEGAChatSdk] chatRoomForChatId:chatListItem.chatId];
                NSString *peerEmail     = [[MEGASdkManager sharedMEGAChatSdk] userEmailByUserHandle:[chatRoom peerHandleAtIndex:0]];
                NSString *peerFirstname = [chatRoom peerFirstnameAtIndex:0];
                NSString *peerLastname  = [chatRoom peerLastnameAtIndex:0];
                NSString *peerName      = [NSString stringWithFormat:@"%@ %@", peerFirstname, peerLastname];
                uint64_t peerHandle     = [chatRoom peerHandleAtIndex:0];
                
                ContactDetailsViewController *contactDetailsVC = [[UIStoryboard storyboardWithName:@"Contacts" bundle:nil] instantiateViewControllerWithIdentifier:@"ContactDetailsViewControllerID"];
                contactDetailsVC.contactDetailsMode = ContactDetailsModeFromChat;
                contactDetailsVC.chatId             = chatRoom.chatId;
                contactDetailsVC.userEmail          = peerEmail;
                contactDetailsVC.userName           = peerName;
                contactDetailsVC.userHandle         = peerHandle;
                [self.navigationController pushViewController:contactDetailsVC animated:YES];
            }
            
        }]];
        
        if ([[UIDevice currentDevice] iPadDevice]) {
            alertController.modalPresentationStyle = UIModalPresentationPopover;
            UIPopoverPresentationController *popoverPresentationController = [alertController popoverPresentationController];
            CGRect moreRect = [self.tableView rectForRowAtIndexPath:indexPath];
            popoverPresentationController.sourceRect = moreRect;
            popoverPresentationController.sourceView = self.tableView;
        }
        [self presentViewController:alertController animated:YES completion:nil];
    }];
    moreAction.backgroundColor = [UIColor mnz_grayCCCCCC];
    
    UITableViewRowAction *deleteAction = nil;
    
    if (chatListItem.isGroup) {
        deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:AMLocalizedString(@"Leave", nil)  handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
            UIAlertController *leaveAlertController = [UIAlertController alertControllerWithTitle:AMLocalizedString(@"Are you sure you want to leave this group chat?", nil) message:nil preferredStyle:UIAlertControllerStyleActionSheet];
            [leaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"cancel", @"Button title to cancel something") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
                [self dismissViewControllerAnimated:YES completion:nil];
                [self.tableView setEditing:NO];
            }]];
            
            [leaveAlertController addAction:[UIAlertAction actionWithTitle:AMLocalizedString(@"Leave", nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [[MEGASdkManager sharedMEGAChatSdk] leaveChat:chatListItem.chatId delegate:self];
                [self.tableView setEditing:NO];
            }]];
            
            if ([[UIDevice currentDevice] iPadDevice]) {
                leaveAlertController.modalPresentationStyle = UIModalPresentationPopover;
                UIPopoverPresentationController *popoverPresentationController = [leaveAlertController popoverPresentationController];
                CGRect deleteRect = [self.tableView rectForRowAtIndexPath:indexPath];
                popoverPresentationController.sourceRect = deleteRect;
                popoverPresentationController.sourceView = self.view;
            }
            [self presentViewController:leaveAlertController animated:YES completion:nil];
        }];
    } else {
        deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:AMLocalizedString(@"Close", nil)  handler:^(UITableViewRowAction *action, NSIndexPath *indexPath) {
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"TODO" message:@"Not implemented yet" preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"ok" style:UIAlertActionStyleCancel handler:nil]];
             [self presentViewController:alertController animated:YES completion:nil];
        }];
    }
    deleteAction.backgroundColor = [UIColor mnz_redFF333A];
    
    return @[deleteAction, moreAction];
}

#pragma mark - MEGAChatRequestDelegate

- (void)onChatRequestFinish:(MEGAChatSdk *)api request:(MEGAChatRequest *)request error:(MEGAChatError *)error {
    if (error.type) return;
    
    switch (request.type) {
        case MEGAChatRequestTypeCreateChatRoom: {
            MEGAChatRoom *chatRoom = [[MEGASdkManager sharedMEGAChatSdk] chatRoomForChatId:request.chatHandle];
            
            MessagesViewController *messagesVC = [[MessagesViewController alloc] init];
            messagesVC.chatRoom                = chatRoom;
            
            [self.navigationController pushViewController:messagesVC animated:YES];
            
            break;
        }
            
        case MEGAChatRequestTypeRemoveFromChatRoom: {
//            MEGAChatRoom *chatRoom = [[MEGASdkManager sharedMEGAChatSdk] chatRoomForChatId:request.chatHandle];
//            NSIndexPath *indexPath = [self.chatListItemIndexPathDictionary objectForKey:@(chatRoom.chatId)];
//            [self.tableView beginUpdates];
//            [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
//            [self.tableView endUpdates];
            break;
        }
            
        default:
            break;
    }
}

#pragma mark - MEGAChatDelegate

- (void)onChatListItemUpdate:(MEGAChatSdk *)api item:(MEGAChatListItem *)item {
    MEGALogInfo(@"onChatListItemUpdate %@", item);
    
    // New chat 1on1 or group
    if (item.changes == 0) {
        [self sortChatListItems];
        [self.tableView reloadData];
    } else {
        NSIndexPath *indexPath = [self.chatListItemIndexPathDictionary objectForKey:@(item.chatId)];
        if ([self.tableView.indexPathsForVisibleRows containsObject:indexPath]) {
            ChatRoomCell *cell = (ChatRoomCell *)[self.tableView cellForRowAtIndexPath:indexPath];
            switch (item.changes) {
                case MEGAChatListItemChangeTypeStatus:
                    if (item.onlineStatus == 0) {
                        cell.onlineStatusView.backgroundColor = [UIColor mnz_gray666666];
                    } else if (item.onlineStatus == 3) {
                        cell.onlineStatusView.backgroundColor = [UIColor mnz_green13E03C];
                    }
                    break;
                    
                case MEGAChatListItemChangeTypeVisibility:
                    break;
                    
                case MEGAChatListItemChangeTypeUnreadCount:
                    if (cell.unreadCount.hidden && item.unreadCount != 0) {
                        cell.unreadCount.hidden             = NO;
                        cell.unreadCount.layer.cornerRadius = 6.0f;
                        cell.unreadCount.clipsToBounds      = YES;
                    }
                    cell.unreadCount.text = [NSString stringWithFormat:@"%ld", (long)item.unreadCount];
                    break;
                    
                case MEGAChatListItemChangeTypeParticipants:
                    break;
                    
                case MEGAChatListItemChangeTypeTitle:
                    cell.chatTitle.text = item.title;
                    break;
                    
                case MEGAChatListItemChangeTypeClosed:
                    //TODO: Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'Invalid update: invalid number of rows in section 0.  The number of rows contained in an existing section after the update (15) must be equal to the number of rows contained in that section before the update (15), plus or minus the number of rows inserted or deleted from that section (0 inserted, 1 deleted) and plus or minus the number of rows moved into or out of that section (0 moved in, 0 moved out).'
                    //                [self.tableView beginUpdates];
                    //                [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
                    //                [self.chatListItemIndexPathDictionary removeObjectForKey:indexPath];
                    //                [self.tableView endUpdates];
                    break;
                    
                case MEGAChatListItemChangeTypeLastMsg: {
                    if (item.lastMessage.isManagementMessage) {
                        cell.chatLastMessage.text = @"Management message";
                    } else {
                        cell.chatLastMessage.text = item.lastMessage.content;
                    }
                    
                    cell.chatLastTime.text = item.lastMessage.timestamp.shortTimeAgoSinceNow;
                    break;
                }
                    
                default:
                    break;
            }
        }
        
        [self sortChatListItems];
        
        if (item.changes == MEGAChatListItemChangeTypeLastMsg) {
            if ([indexPath compare:[NSIndexPath indexPathForRow:0 inSection:0]] != NSOrderedSame) {
                [self.tableView moveRowAtIndexPath:indexPath toIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
            }
        }
    }
}

@end
