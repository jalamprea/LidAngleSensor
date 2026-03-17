//
//  AppDelegate.m
//  LidAngleSensor
//
//  Created by Sam on 2025-09-06.
//

#import "AppDelegate.h"
#import "LidAngleSensor.h"
#import "CreakAudioEngine.h"
#import "ThereminAudioEngine.h"

typedef NS_ENUM(NSInteger, AudioMode) {
    AudioModeCreak,
    AudioModeTheremin
};

@interface AppDelegate ()
@property (strong, nonatomic) NSStatusItem *statusItem;
@property (strong, nonatomic) NSMenu *statusMenu;
@property (strong, nonatomic) LidAngleSensor *lidSensor;
@property (strong, nonatomic) CreakAudioEngine *creakAudioEngine;
@property (strong, nonatomic) ThereminAudioEngine *thereminAudioEngine;
@property (strong, nonatomic) NSTimer *updateTimer;
@property (nonatomic, assign) AudioMode currentAudioMode;

// Menu items that need updating
@property (strong, nonatomic) NSMenuItem *velocityItem;
@property (strong, nonatomic) NSMenuItem *statusItem_menu;
@property (strong, nonatomic) NSMenuItem *audioParamsItem;
@property (strong, nonatomic) NSMenuItem *audioToggleItem;
@property (strong, nonatomic) NSMenuItem *creakModeItem;
@property (strong, nonatomic) NSMenuItem *thereminModeItem;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    self.currentAudioMode = AudioModeCreak;
    [self createStatusItem];
    [self initializeLidSensor];
    [self initializeAudioEngines];
    [self startUpdatingDisplay];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    [self.updateTimer invalidate];
    [self.lidSensor stopLidAngleUpdates];
    [self.creakAudioEngine stopEngine];
    [self.thereminAudioEngine stopEngine];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
    return YES;
}

#pragma mark - Status Item Setup

- (void)createStatusItem {
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

    // Set initial title
    self.statusItem.button.title = @"--°";
    self.statusItem.button.font = [NSFont monospacedDigitSystemFontOfSize:0 weight:NSFontWeightRegular];

    // Use a template image if available on this OS version
    if (@available(macOS 11.0, *)) {
        NSImage *image = [NSImage imageWithSystemSymbolName:@"macbook" accessibilityDescription:@"Lid Angle"];
        if (image) {
            self.statusItem.button.image = image;
            self.statusItem.button.imagePosition = NSImageLeading;
        }
    }

    // Build the dropdown menu
    [self buildMenu];
    self.statusItem.menu = self.statusMenu;
}

- (void)buildMenu {
    self.statusMenu = [[NSMenu alloc] init];

    // Velocity display
    self.velocityItem = [[NSMenuItem alloc] initWithTitle:@"Velocity: 00 deg/s" action:nil keyEquivalent:@""];
    [self.velocityItem setEnabled:NO];
    [self.statusMenu addItem:self.velocityItem];

    // Status display
    self.statusItem_menu = [[NSMenuItem alloc] initWithTitle:@"Detecting sensor..." action:nil keyEquivalent:@""];
    [self.statusItem_menu setEnabled:NO];
    [self.statusMenu addItem:self.statusItem_menu];

    // Audio parameters display
    self.audioParamsItem = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    [self.audioParamsItem setEnabled:NO];
    [self.audioParamsItem setHidden:YES];
    [self.statusMenu addItem:self.audioParamsItem];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    // Audio toggle
    self.audioToggleItem = [[NSMenuItem alloc] initWithTitle:@"Start Audio" action:@selector(toggleAudio:) keyEquivalent:@""];
    [self.audioToggleItem setTarget:self];
    [self.statusMenu addItem:self.audioToggleItem];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    // Audio mode header
    NSMenuItem *modeHeader = [[NSMenuItem alloc] initWithTitle:@"Audio Mode" action:nil keyEquivalent:@""];
    [modeHeader setEnabled:NO];
    [self.statusMenu addItem:modeHeader];

    // Creak mode
    self.creakModeItem = [[NSMenuItem alloc] initWithTitle:@"Creak" action:@selector(selectCreakMode:) keyEquivalent:@""];
    [self.creakModeItem setTarget:self];
    [self.creakModeItem setState:NSControlStateValueOn];
    [self.statusMenu addItem:self.creakModeItem];

    // Theremin mode
    self.thereminModeItem = [[NSMenuItem alloc] initWithTitle:@"Theremin" action:@selector(selectThereminMode:) keyEquivalent:@""];
    [self.thereminModeItem setTarget:self];
    [self.thereminModeItem setState:NSControlStateValueOff];
    [self.statusMenu addItem:self.thereminModeItem];

    [self.statusMenu addItem:[NSMenuItem separatorItem]];

    // Quit
    NSMenuItem *quitItem = [[NSMenuItem alloc] initWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    [quitItem setTarget:NSApp];
    [self.statusMenu addItem:quitItem];
}

#pragma mark - Sensor & Audio Init

- (void)initializeLidSensor {
    self.lidSensor = [[LidAngleSensor alloc] init];

    if (self.lidSensor.isAvailable) {
        [self.statusItem_menu setTitle:@"Sensor detected"];
    } else {
        [self.statusItem_menu setTitle:@"Sensor not available"];
        self.statusItem.button.title = @"N/A";
    }
}

- (void)initializeAudioEngines {
    self.creakAudioEngine = [[CreakAudioEngine alloc] init];
    self.thereminAudioEngine = [[ThereminAudioEngine alloc] init];

    if (!self.creakAudioEngine || !self.thereminAudioEngine) {
        [self.audioToggleItem setEnabled:NO];
        [self.audioToggleItem setTitle:@"Audio unavailable"];
    }
}

#pragma mark - Audio Controls

- (void)toggleAudio:(id)sender {
    id currentEngine = [self currentAudioEngine];
    if (!currentEngine) return;

    if ([currentEngine isEngineRunning]) {
        [currentEngine stopEngine];
        [self.audioToggleItem setTitle:@"Start Audio"];
        [self.audioParamsItem setHidden:YES];
    } else {
        [currentEngine startEngine];
        [self.audioToggleItem setTitle:@"Stop Audio"];
    }
}

- (void)selectCreakMode:(id)sender {
    [self switchToMode:AudioModeCreak];
}

- (void)selectThereminMode:(id)sender {
    [self switchToMode:AudioModeTheremin];
}

- (void)switchToMode:(AudioMode)newMode {
    if (self.currentAudioMode == newMode) return;

    id currentEngine = [self currentAudioEngine];
    BOOL wasRunning = [currentEngine isEngineRunning];
    if (wasRunning) {
        [currentEngine stopEngine];
    }

    self.currentAudioMode = newMode;

    // Update checkmarks
    [self.creakModeItem setState:(newMode == AudioModeCreak) ? NSControlStateValueOn : NSControlStateValueOff];
    [self.thereminModeItem setState:(newMode == AudioModeTheremin) ? NSControlStateValueOn : NSControlStateValueOff];

    if (wasRunning) {
        [[self currentAudioEngine] startEngine];
        [self.audioToggleItem setTitle:@"Stop Audio"];
    }
}

- (id)currentAudioEngine {
    switch (self.currentAudioMode) {
        case AudioModeCreak:
            return self.creakAudioEngine;
        case AudioModeTheremin:
            return self.thereminAudioEngine;
        default:
            return self.creakAudioEngine;
    }
}

#pragma mark - Display Updates

- (void)startUpdatingDisplay {
    self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:0.016
                                                        target:self
                                                      selector:@selector(updateAngleDisplay)
                                                      userInfo:nil
                                                       repeats:YES];
}

- (void)updateAngleDisplay {
    if (!self.lidSensor.isAvailable) return;

    double angle = [self.lidSensor lidAngle];

    if (angle == -2.0) {
        self.statusItem.button.title = @"Err";
        [self.statusItem_menu setTitle:@"Failed to read sensor data"];
    } else {
        // Update menu bar title with angle
        self.statusItem.button.title = [NSString stringWithFormat:@"%.1f°", angle];

        // Update current audio engine with new angle
        id currentEngine = [self currentAudioEngine];
        if (currentEngine) {
            [currentEngine updateWithLidAngle:angle];

            // Update velocity display
            double velocity = [currentEngine currentVelocity];
            int roundedVelocity = (int)round(velocity);
            if (roundedVelocity < 100) {
                [self.velocityItem setTitle:[NSString stringWithFormat:@"Velocity: %02d deg/s", roundedVelocity]];
            } else {
                [self.velocityItem setTitle:[NSString stringWithFormat:@"Velocity: %d deg/s", roundedVelocity]];
            }

            // Show audio parameters when running
            if ([currentEngine isEngineRunning]) {
                [self.audioParamsItem setHidden:NO];
                if (self.currentAudioMode == AudioModeCreak) {
                    double gain = [currentEngine currentGain];
                    double rate = [currentEngine currentRate];
                    [self.audioParamsItem setTitle:[NSString stringWithFormat:@"Gain: %.2f, Rate: %.2f", gain, rate]];
                } else if (self.currentAudioMode == AudioModeTheremin) {
                    double frequency = [currentEngine currentFrequency];
                    double volume = [currentEngine currentVolume];
                    [self.audioParamsItem setTitle:[NSString stringWithFormat:@"Freq: %.1f Hz, Vol: %.2f", frequency, volume]];
                }
            }
        }

        // Contextual status based on angle
        NSString *status;
        if (angle < 5.0) {
            status = @"Lid is closed";
        } else if (angle < 45.0) {
            status = @"Lid slightly open";
        } else if (angle < 90.0) {
            status = @"Lid partially open";
        } else if (angle < 120.0) {
            status = @"Lid mostly open";
        } else {
            status = @"Lid fully open";
        }
        [self.statusItem_menu setTitle:status];
    }
}

@end
