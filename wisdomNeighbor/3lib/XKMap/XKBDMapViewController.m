//
//  XKBDMapViewController.m
//  XKBDMap
//
//  Created by hupan on 2018/7/26.
//  Copyright © 2018年 Tears. All rights reserved.
//

#import "XKBDMapViewController.h"
#import <MapKit/MapKit.h>
#import <BaiduMapAPI_Map/BMKMapComponent.h>
#import <BaiduMapAPI_Base/BMKBaseComponent.h>
#import "XKCoordinateTransformation.h"
#import "XKMapManager.h"
#import "XKBaiduMapView.h"
#import "UIView+ShadowPath.h"
#import "XKMapLocationDelegate.h"


@interface XKBDMapViewController () <BMKMapViewDelegate,XKMapLocationDelegate>

@property (nonatomic, strong) BMKMapView        *mapView;
@property (nonatomic, copy  ) NSArray           *mapArr;
@property (nonatomic,strong ) BMKAnnotationView *selectAnnotation;



@end

@implementation XKBDMapViewController


#pragma mark - Life Cycle

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setNavTitle:self.destinationName.length ? self.destinationName : @"地图" WithColor:[UIColor whiteColor]];
    [self configMapView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear: animated];
    //当mapView即将被显示的时候调用，恢复之前存储的mapView状态
    [_mapView viewWillAppear];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear: animated];
    //当mapView即将被隐藏的时候调用，存储当前mapView的状态
    [_mapView viewWillDisappear];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Private Metheods

- (void)configMapView {
    
    BMKPointAnnotation *annotation = [[BMKPointAnnotation alloc] init];
    CLLocationCoordinate2D coor;
    coor.latitude = self.destinationLatitude;
    coor.longitude = self.destinationLongitude;
    annotation.coordinate = coor;
    [self.mapView addAnnotation:annotation];
    [self.mapView setCenterCoordinate:coor animated:YES];
    
    
    /*
    for (int i = 0; i < 3; i++) {
        
        BMKPointAnnotation* annotation = [[BMKPointAnnotation alloc] init];
        CLLocationCoordinate2D coor;
        coor.latitude = self.destinationLatitude + (i+1)*0.0003;
        coor.longitude = self.destinationLongitude + (i+1)*0.0002;
        annotation.coordinate = coor;
        [self.mapView addAnnotation:annotation];
    }*/
    
    CGRect screenRect = [UIScreen mainScreen].bounds;
    UIButton *guideButton = [[UIButton alloc] initWithFrame:CGRectMake(screenRect.size.width - 100, screenRect.size.height - 80, 100, 36)];
    [guideButton setTitle:@"使用其他地图" forState:UIControlStateNormal];
    [guideButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    guideButton.backgroundColor = RGBA(34, 34, 34, 0.7);
    guideButton.titleLabel.font = XKRegularFont(14);
    
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:guideButton.bounds byRoundingCorners:UIRectCornerTopLeft | UIRectCornerBottomLeft cornerRadii:CGSizeMake(18, 18)];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.path = maskPath.CGPath;
    guideButton.layer.mask = maskLayer;
    
    [self.view addSubview:guideButton];
    [guideButton addTarget:self action:@selector(guideButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    
}

- (void)configBaiduMapLocation {
    [[[XKMapManager getCurrentMapFactory] getMapLocation] setLocationDelegate:self];
    [[[XKMapManager getCurrentMapFactory] getMapLocation] startBaiduSingleLocationService];
}

#pragma mark - XKMapLocationDelegate

- (void)userLocationLaititude:(double)laititude longtitude:(double)longtitude {
    [XKHudView hideHUDForView:self.view];
    self.myLatitude = laititude;
    self.myLongitude = longtitude;
    
    [self showMapAlrentView];
}

- (void)failToLocateUserWithError:(NSError *)error {
    [XKHudView hideHUDForView:self.view];
    [XKHudView showErrorMessage:@"定位失败！"];
}

- (void)guideButtonClicked {
    if (self.myLatitude == 0 && self.myLongitude == 0) {
        if ([[[XKMapManager getCurrentMapFactory] getMapLocation] locationAuthorized]) {
            //开启网络加载提示   定位结束或者失败时关闭
            [XKHudView showLoadingTo:self.view animated:YES];
            [self configBaiduMapLocation];
        }
    } else {
        [self showMapAlrentView];
    }
}
- (void)showMapAlrentView {
    
    if (!self.mapArr) {
        self.mapArr = [self getInstalledMapApp];
    }
    NSString *message = nil;
    if (self.mapArr.count == 0) {
        message = @"您本机暂无地图可使用！";
    }
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:(UIAlertControllerStyleActionSheet)];
    __weak typeof(alertController) weakAlert = alertController;
    XKWeakSelf(weakSelf);
    for (NSDictionary *dic in self.mapArr) {
        UIAlertAction * action = [UIAlertAction actionWithTitle:dic[@"title"] style:(UIAlertActionStyleDefault) handler:^(UIAlertAction * _Nonnull action) {
            NSInteger index = [weakAlert.actions indexOfObject:action];
            if (index < weakSelf.mapArr.count) {
                NSDictionary *mapDic = weakSelf.mapArr[index];
                if ([mapDic[@"title"] isEqualToString:@"苹果地图"]) {
                    [weakSelf navAppleMap];
                    return;
                }
                NSString *urlString = mapDic[@"url"];
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString] options:@{} completionHandler:nil];
            }
        }];
        [alertController addAction:action];
    }
    UIAlertAction * cancelAction = [UIAlertAction actionWithTitle:@"取消" style:(UIAlertActionStyleCancel) handler:nil];
    [alertController addAction:cancelAction];
    [self presentViewController:alertController animated:YES completion:nil];
}

//苹果地图
- (void)navAppleMap {
    
    CLLocationCoordinate2D coordinate2D = [XKCoordinateTransformation transfromFromBD09ToGCJ02WithBD09Latitide:self.destinationLatitude BD09Longitude:self.destinationLongitude];

    MKMapItem *currentLoc = [MKMapItem mapItemForCurrentLocation];
    MKMapItem *toLocation = [[MKMapItem alloc] initWithPlacemark:[[MKPlacemark alloc] initWithCoordinate:coordinate2D addressDictionary:nil]];
    NSArray *items = @[currentLoc,toLocation];
    NSDictionary *dic = @{
                          MKLaunchOptionsDirectionsModeKey : MKLaunchOptionsDirectionsModeDriving,
                          MKLaunchOptionsMapTypeKey : @(MKMapTypeStandard),
                          MKLaunchOptionsShowsTrafficKey : @(YES)
                          };

    [MKMapItem openMapsWithItems:items launchOptions:dic];
}


- (NSArray *)getInstalledMapApp {

    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    // app名称
    NSString *app_Name = [infoDictionary objectForKey:@"CFBundleDisplayName"];
    
    NSMutableArray *maps = [NSMutableArray array];
    
    
    //百度地图
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"baidumap://"]]) {
        NSMutableDictionary *baiduMapDic = [NSMutableDictionary dictionary];
        baiduMapDic[@"title"] = @"百度地图";
        
        NSString *urlString = [[NSString stringWithFormat:@"baidumap://map/direction?origin=latlng:%f,%f|name:我的位置&destination=latlng:%f,%f|name:%@&mode=driving", self.myLatitude,self.myLongitude, self.destinationLatitude, self.destinationLongitude, self.destinationName] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        baiduMapDic[@"url"] = urlString;
        [maps addObject:baiduMapDic];
    }
    CLLocationCoordinate2D coordinate2D = [XKCoordinateTransformation transfromFromBD09ToGCJ02WithBD09Latitide:self.destinationLatitude BD09Longitude:self.destinationLongitude];
    double TFLatitude = coordinate2D.latitude;
    double TFLongitude = coordinate2D.longitude;
    
    
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"http://maps.apple.com"]]) {
        //苹果地图
        NSMutableDictionary *iosMapDic = [NSMutableDictionary dictionary];
        iosMapDic[@"title"] = @"苹果地图";
        [maps addObject:iosMapDic];
    }
    
    //高德地图
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"iosamap://"]]) {
        NSMutableDictionary *gaodeMapDic = [NSMutableDictionary dictionary];
        gaodeMapDic[@"title"] = @"高德地图";
        
        NSString *urlString = [[NSString stringWithFormat:@"iosamap://path?sourceApplication=%@&&backScheme=%@&sid=BGVIS1&slat=%lf&slon=%lf&sname=我的位置&did=BGVIS2&dlat=%lf&dlon=%lf&dname=%@&dev=0&m=0&t=0", app_Name, @"iosamap", self.myLatitude, self.myLongitude, TFLatitude, TFLongitude, self.destinationName] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        gaodeMapDic[@"url"] = urlString;
        [maps addObject:gaodeMapDic];
    }
    
    //谷歌地图
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"comgooglemaps://"]]) {
        NSMutableDictionary *googleMapDic = [NSMutableDictionary dictionary];
        googleMapDic[@"title"] = @"谷歌地图";
        NSString *urlString = [[NSString stringWithFormat:@"comgooglemaps://?x-source=%@&x-success=%@&saddr=&daddr=%f,%f&directionsmode=driving", @"导航测试", @"nav123456", self.myLatitude, self.myLongitude] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        googleMapDic[@"url"] = urlString;
        [maps addObject:googleMapDic];
    }
    
    //腾讯地图
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"qqmap://"]]) {
        NSMutableDictionary *qqMapDic = [NSMutableDictionary dictionary];
        qqMapDic[@"title"] = @"腾讯地图";
        NSString *urlString = [[NSString stringWithFormat:@"qqmap://map/routeplan?from=我的位置&type=drive&tocoord=%f,%f&to=%@&coord_type=1&policy=0", TFLatitude,  TFLongitude, self.destinationName] stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        qqMapDic[@"url"] = urlString;
        [maps addObject:qqMapDic];
    }
    
    return [maps copy];
}



#pragma mark - BMKMapViewDelegate

- (void)mapView:(BMKMapView *)mapView didSelectAnnotationView:(BMKAnnotationView *)view {
    
    /*
    view.image = [UIImage imageNamed:@"xk_icon_store_address"];
    if (self.selectAnnotation) {
        self.selectAnnotation.image = [UIImage imageNamed:@"xk_icon_store_address"];
    }
    self.selectAnnotation = view;*/
        
    
    [self.mapView setCenterCoordinate:view.annotation.coordinate animated:YES];

}


- (BMKAnnotationView *)mapView:(BMKMapView *)mapView viewForAnnotation:(id <BMKAnnotation>)annotation {
    
    if ([annotation isKindOfClass:[BMKPointAnnotation class]]) {
        
        BMKPinAnnotationView *newAnationView = (BMKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"myAnnotation"];
    
        if (!newAnationView) {
            newAnationView = [[BMKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"myAnnotation"];
            //直接显示,不用点击弹出
            [newAnationView setSelected:YES];
            newAnationView.animatesDrop = YES;
    
            UIView *popView = [self creatPopView];
            BMKActionPaopaoView *pView = [[BMKActionPaopaoView alloc] initWithCustomView:popView];
            pView.frame = popView.bounds;
            newAnationView.paopaoView = pView;
            newAnationView.image = [UIImage imageNamed:@"xk_icon_tradingArea_storeAdr"];
        }

        return newAnationView;
    }
    return nil;
}


- (UIView *)creatPopView {
    CGFloat height;
    if (self.destinationDec.length) {
        height = 60;
    } else {
        height = 35;
    }
    UIView *totalView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 210, height + 8)];
    UIImageView *downImgView = [[UIImageView alloc] initWithFrame:CGRectMake((210 - 8) / 2, height, 8, 6)];
    downImgView.image = [UIImage imageNamed:@"xk_icon_tradingArea_adrDown"];
    
    UIView *popView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 210, height)];
    popView.backgroundColor = [UIColor whiteColor];
    [popView drawShadowPathWithShadowColor:HEX_RGB(0x000000) shadowOpacity:0.2 shadowRadius:5.0 shadowPathWidth:2.0 shadowOffset:CGSizeMake(0,1)];
//    popView.layer.masksToBounds = YES;
//    popView.layer.cornerRadius = 5;
    
    /*
    //设置弹出气泡背景图片
    NSInteger guideBtnWidth = 60;
    UIButton *guideButton = [[UIButton alloc] initWithFrame:CGRectMake(popView.frame.size.width - guideBtnWidth, 0, guideBtnWidth, popView.frame.size.height)];
    [guideButton setTitle:@"查看路线" forState:UIControlStateNormal];
    guideButton.titleLabel.font = [UIFont systemFontOfSize:14];
    guideButton.backgroundColor = XKMainTypeColor;
    [guideButton addTarget:self action:@selector(guideButtonClicked) forControlEvents:UIControlEventTouchUpInside];
    [popView addSubview:guideButton];
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = self.destinationName;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont systemFontOfSize:14];
    titleLabel.numberOfLines = 2;
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.frame = CGRectMake(0, 0, popView.frame.size.width - guideBtnWidth, popView.frame.size.height);
     */
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.numberOfLines = 2;
    titleLabel.frame = CGRectMake(10, 5, popView.frame.size.width-20, popView.frame.size.height-10);
    [titleLabel rz_colorfulConfer:^(RZColorfulConferrer * _Nonnull confer) {
        confer.paragraphStyle.alignment(NSTextAlignmentLeft).lineSpacing(4);
        confer.text(self.destinationName).textColor(HEX_RGB(0x000000)).font(XKRegularFont(15));
        if (self.destinationDec.length) {
            confer.text(@"\n");
            confer.text(self.destinationDec).textColor(HEX_RGB(0x555555)).font(XKRegularFont(12));
        }
    }];
    [popView addSubview:titleLabel];
    [totalView addSubview:popView];
    [totalView addSubview:downImgView];
    
    return totalView;
}



#pragma mark - Lazy load

- (BMKMapView *)mapView {
    if (!_mapView) {
        XKBaiduMapView *baiduView = (XKBaiduMapView *)[[XKMapManager getCurrentMapFactory] getMapViewWithFrame:CGRectMake(0, NavigationAndStatue_Height, SCREEN_WIDTH, SCREEN_HEIGHT-NavigationAndStatue_Height)];
        _mapView = baiduView.bmkMapView;
        _mapView.delegate = self;
    
        if (self.locationMerchantArray.count) {
            _mapView.zoomLevel = 14;
        } else {
            _mapView.zoomLevel = 18;
        }
        _mapView.showsUserLocation = YES;
        [self.view addSubview:_mapView];
    }
    return _mapView;
}

- (BMKAnnotationView *)selectAnnotation {
    if (!_selectAnnotation) {
        _selectAnnotation = [[BMKAnnotationView alloc] init];
    }
    return _selectAnnotation;
}


@end
