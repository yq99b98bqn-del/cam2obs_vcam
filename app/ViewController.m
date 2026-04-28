#import "ViewController.h"
#import <notify.h>

@interface ViewController ()
@property (nonatomic, strong) UISwitch *toggleSwitch;
@property (nonatomic, strong) UILabel *statusLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Icon-App-60x60@2x"]];
    icon.center = CGPointMake(self.view.bounds.size.width/2, 180);
    icon.layer.cornerRadius = 20;
    icon.clipsToBounds = YES;
    [self.view addSubview:icon];
    
    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 250, self.view.bounds.size.width, 30)];
    self.statusLabel.text = @"Ảo camera: TẮT";
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:self.statusLabel];
    
    self.toggleSwitch = [[UISwitch alloc] init];
    self.toggleSwitch.center = CGPointMake(self.view.bounds.size.width/2, 320);
    [self.toggleSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.toggleSwitch];
    
    UILabel *help = [[UILabel alloc] initWithFrame:CGRectMake(20, 400, self.view.bounds.size.width-40, 80)];
    help.text = @"Kết nối OBS:\n1. Máy tính: iproxy 9999 9999\n2. OBS phát MJPEG tới cổng 9999\n3. iPhone mở app bất kỳ (Camera, TikTok...) sẽ thấy video từ OBS.";
    help.textColor = [UIColor grayColor];
    help.numberOfLines = 0;
    help.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:help];
}

- (void)switchChanged:(UISwitch *)sender {
    Boolean state = sender.isOn;
    self.statusLabel.text = state ? @"Ảo camera: BẬT" : @"Ảo camera: TẮT";
    notify_post("com.yourcompany.cam2obs.vcam.toggle");
}
@end