//
//  NSManagedObjectContext+MagicalObserving.m
//  Magical Record
//
//  Created by Saul Mora on 3/9/12.
//  Copyright (c) 2012 Magical Panda Software LLC. All rights reserved.
//

#import "NSManagedObjectContext+MagicalObserving.h"
#import "NSManagedObjectContext+MagicalRecord.h"
#import "MagicalRecord.h"
#import "MagicalRecord+iCloud.h"
#import "MagicalRecordLogging.h"

NSString * const kMagicalRecordDidMergeChangesFromiCloudNotification = @"kMagicalRecordDidMergeChangesFromiCloudNotification";

@implementation NSManagedObjectContext (MagicalObserving)

#pragma mark - Context Observation Helpers

- (void) MR_observeContext:(NSManagedObjectContext *)otherContext
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self
                           selector:@selector(MR_mergeChangesFromNotification:)
                               name:NSManagedObjectContextDidSaveNotification
                             object:otherContext];
}

- (void) MR_stopObservingContext:(NSManagedObjectContext *)otherContext
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

	[notificationCenter removeObserver:self
                                  name:NSManagedObjectContextDidSaveNotification
                                object:otherContext];
}

- (void) MR_observeContextOnMainThread:(NSManagedObjectContext *)otherContext
{
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	[notificationCenter addObserver:self
                           selector:@selector(MR_mergeChangesOnMainThread:)
                               name:NSManagedObjectContextDidSaveNotification
                             object:otherContext];
}

#pragma mark - Context iCloud Merge Helpers

- (void) MR_mergeChangesFromiCloud:(NSNotification *)notification;
{
    [self performBlock:^{
        
        MRLogVerbose(@"Merging changes From iCloud %@context%@",
              self == [NSManagedObjectContext MR_defaultContext] ? @"*** DEFAULT *** " : @"",
              ([NSThread isMainThread] ? @" *** on Main Thread ***" : @""));
        
        [self mergeChangesFromContextDidSaveNotification:notification];
        
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];

        [notificationCenter postNotificationName:kMagicalRecordDidMergeChangesFromiCloudNotification
                                          object:self
                                        userInfo:[notification userInfo]];
    }];
}

- (void) MR_mergeChangesFromNotification:(NSNotification *)notification;
{
	MRLogVerbose(@"Merging changes to %@context%@",
          self == [NSManagedObjectContext MR_defaultContext] ? @"*** DEFAULT *** " : @"",
          ([NSThread isMainThread] ? @" *** on Main Thread ***" : @""));
    
	[self mergeChangesFromContextDidSaveNotification:notification];

 
  //Source: http://stackoverflow.com/questions/16296364/nsfetchedresultscontroller-is-not-showing-all-results-after-merging-an-nsmanage
  //BUG FIX: When the notification is merged it only updates objects which are already registered in the context.
  //If the predicate for a NSFetchedResultsController matches an updated object but the object is not registered
  //in the FRC's context then the FRC will fail to include the updated object. The fix is to force all updated
  //objects to be refreshed in the context thus making them available to the FRC.
  //Note that we have to be very careful about which methods we call on the managed objects in the notifications userInfo.
  for (NSManagedObject *unsafeManagedObject in notification.userInfo[NSUpdatedObjectsKey]) {
    //Force the refresh of updated objects which may not have been registered in this context.
    NSManagedObject *manangedObject = [self existingObjectWithID:unsafeManagedObject.objectID error:NULL];
    if (manangedObject != nil) {
      [self refreshObject:manangedObject mergeChanges:YES];
    }
  }


}

- (void) MR_mergeChangesOnMainThread:(NSNotification *)notification;
{
	if ([NSThread isMainThread])
	{
		[self MR_mergeChangesFromNotification:notification];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(MR_mergeChangesFromNotification:) withObject:notification waitUntilDone:YES];
	}
}

- (void) MR_observeiCloudChangesInCoordinator:(NSPersistentStoreCoordinator *)coordinator;
{
    if (![MagicalRecord isICloudEnabled]) return;
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(MR_mergeChangesFromiCloud:)
                               name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                             object:coordinator];
    
}

- (void) MR_stopObservingiCloudChangesInCoordinator:(NSPersistentStoreCoordinator *)coordinator;
{
    if (![MagicalRecord isICloudEnabled]) return;
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self
                                  name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                                object:coordinator];
}

@end
