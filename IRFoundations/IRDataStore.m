//
//  IRDataStore.m
//  IRFoundations
//
//  Created by Evadne Wu on 7/21/11.
//  Copyright 2011 Iridia Productions. All rights reserved.
//

#import "IRDataStore.h"
#import <TargetConditionals.h>

#import <CoreData/CoreData.h>
#import <objc/runtime.h>

#import "IRManagedObjectContext.h"
#import "IRLifetimeHelper.h"


NSString * const kIRDataStore_DefaultAutoUpdatedMOC = @"IRDataStore_DefaultAutoUpdatedMOC";

@interface IRDataStore ()

@property (nonatomic, readwrite, strong) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, readwrite, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;
#if OS_OBJECT_USE_OBJC
@property (nonatomic, readwrite, strong) dispatch_queue_t dispatchQueue;
#else
@property (nonatomic, readwrite, assign) dispatch_queue_t dispatchQueue;
#endif

@end

@implementation IRDataStore

@synthesize managedObjectModel, persistentStoreCoordinator;
@synthesize persistentStoreName;
@synthesize dispatchQueue;

+ (IRDataStore *) defaultStore {

	static dispatch_once_t predicate = 0; 
	static id returned = nil;
	
	dispatch_once(&predicate, ^ {
		returned = [[self alloc] init];
	});
	
	return returned;

}

- (IRDataStore *) init {

	self = [self initWithManagedObjectModel:nil];
	if (!self)
		return nil;
	
	return self;

}

- (NSManagedObjectModel *) defaultManagedObjectModel {

	[NSException raise:NSInternalInconsistencyException format:@"Subclasses shall provide a custom managed object model."];
	return nil;

}

- (NSURL *) defaultPersistentStoreURL {

	NSString *defaultFilename = [self.persistentStoreName stringByAppendingPathExtension:@"sqlite"];
	NSParameterAssert(defaultFilename);
	
#if TARGET_OS_MAC
	
	NSString *usedAppName = [[[NSBundle mainBundle] infoDictionary] objectForKey:(id)kCFBundleNameKey];
	if (!usedAppName)
		usedAppName = [[NSBundle mainBundle] bundleIdentifier];

	if (!usedAppName) {
		//	Could be in test cases
		usedAppName = [[NSBundle bundleForClass:(id)[self class]] bundleIdentifier];
	}
	
	NSParameterAssert(usedAppName);

	return [[(NSURL *)[[[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:usedAppName] URLByAppendingPathComponent:defaultFilename];
	
#else
	
	return [(NSURL *)[[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject] URLByAppendingPathComponent:defaultFilename];
	
#endif

}

- (IRDataStore *) initWithManagedObjectModel:(NSManagedObjectModel *)model {

	self = [super init];
	if (!self)
		return nil;
	
	persistentStoreName = [[[NSBundle mainBundle] bundleIdentifier] copy];
	if (!persistentStoreName)
		persistentStoreName = [@"PersistentStore" copy];
	
	managedObjectModel = model;
	
	dispatchQueue = dispatch_queue_create("com.iridia.dataStore.queue", DISPATCH_QUEUE_SERIAL);

	return self;

}


#if OS_OBJECT_USE_OBJC

#else

- (void) dealloc {

	if (dispatchQueue)
		dispatch_release(dispatchQueue);

}

#endif

- (NSManagedObjectModel *) managedObjectModel {

	if (managedObjectModel)
		return managedObjectModel;

	managedObjectModel = [self defaultManagedObjectModel];
	return managedObjectModel;

}

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {

	if (persistentStoreCoordinator)
		return persistentStoreCoordinator;

	persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
	NSURL *storeURL = [self defaultPersistentStoreURL];
	
	BOOL continuesTrying = YES;
	
	while (continuesTrying) {
	
		[[NSFileManager defaultManager] createDirectoryAtPath:[[storeURL path] stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
				
		NSError *persistentStoreAddingError = nil;
		NSPersistentStore *addedStore = [self.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:[NSDictionary dictionaryWithObjectsAndKeys:
		
			(id)kCFBooleanTrue, NSMigratePersistentStoresAutomaticallyOption,
			(id)kCFBooleanTrue, NSInferMappingModelAutomaticallyOption,
		
		nil] error:&persistentStoreAddingError];
		
		NSFileManager *fileManager = [NSFileManager defaultManager];
		
		if (!addedStore) {
		
			NSLog(@"Error adding persistent store: %@", persistentStoreAddingError);
				
			if ([fileManager fileExistsAtPath:[storeURL path]]) {
			
				[fileManager removeItemAtURL:storeURL error:nil];
				continuesTrying = YES;
		
			} else {
			
				continuesTrying = NO;
			
			}
			
		} else {
		
			continuesTrying = NO;
		
		};
	
	}
	
	//	At this point, things might be okay
	//	Let’s save to the file at least once
	
	NSParameterAssert([persistentStoreCoordinator.persistentStores count]);
	return persistentStoreCoordinator;

}

- (void) setPersistentStoreName:(NSString *)newPersistentStoreName {

	if ([persistentStoreName isEqual:newPersistentStoreName])
		return;
	
	persistentStoreName = [newPersistentStoreName copy];

	self.persistentStoreCoordinator = nil;
	objc_setAssociatedObject(self, &kIRDataStore_DefaultAutoUpdatedMOC, nil, OBJC_ASSOCIATION_ASSIGN);
		
}

- (NSManagedObjectContext *) newContextWithConcurrencyType:(NSManagedObjectContextConcurrencyType)type {

	IRManagedObjectContext *returnedContext = [[IRManagedObjectContext alloc] initWithConcurrencyType:type];
	[returnedContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
	[returnedContext setUndoManager:nil];
	
	return returnedContext;

}

- (NSManagedObjectContext *) defaultAutoUpdatedMOC {

	IRManagedObjectContext *returnedContext = objc_getAssociatedObject(self, &kIRDataStore_DefaultAutoUpdatedMOC);
	
	if (!returnedContext) {
	
		__weak IRManagedObjectContext *wContext = returnedContext;
	
		returnedContext = (IRManagedObjectContext *)[self newContextWithConcurrencyType:NSMainQueueConcurrencyType];
		[returnedContext irBeginMergingFromSavesAutomatically];
		[returnedContext irPerformOnDeallocation: ^ {
			[wContext irStopMergingFromSavesAutomatically];
		}];
		
		objc_setAssociatedObject(self, &kIRDataStore_DefaultAutoUpdatedMOC, returnedContext, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	
	}
	
	return returnedContext;

}

- (NSManagedObjectContext *) disposableMOC {

	return [self newContextWithConcurrencyType:NSPrivateQueueConcurrencyType];

}

- (void) performBlock:(void(^)(void))block waitUntilDone:(BOOL)waitsUntilDone {

	if (waitsUntilDone) {
	
		dispatch_sync(self.dispatchQueue, block);
	
	} else {
	
		dispatch_async(self.dispatchQueue, block);
		
	}

}

NSString * IRDataStoreTimestamp () {

	return [NSString stringWithFormat:@"%lu", time(NULL)];

}

NSString * IRDataStoreNonce () {

	NSString *uuid = nil;
	CFUUIDRef theUUID = CFUUIDCreate(kCFAllocatorDefault);
	
	if (!theUUID)
		return nil;
	
	uuid = (__bridge_transfer NSString *)CFUUIDCreateString(kCFAllocatorDefault, theUUID);
	CFRelease(theUUID);
	
	return [NSString stringWithFormat:@"%@-%@", IRDataStoreTimestamp(), uuid];
	
}

@end
