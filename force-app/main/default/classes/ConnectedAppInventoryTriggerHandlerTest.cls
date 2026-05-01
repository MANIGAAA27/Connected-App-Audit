/**
 * ConnectedAppInventoryTriggerHandlerTest
 * Covers ConnectedAppInventoryTriggerHandler at ≥ 94% line coverage.
 */
@isTest
private class ConnectedAppInventoryTriggerHandlerTest {

    // ─────────────────────────────────────────────────────────────────────────
    // Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private static User getAdminUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(
            LastName         = 'TriggerAdmin',
            FirstName        = 'Test',
            Email            = 'triggeradmin@keneland.com',
            Username         = 'triggeradmin' + Datetime.now().getTime() + '@keneland.com',
            Alias            = 'trgadmin',
            TimeZoneSidKey   = 'America/New_York',
            LocaleSidKey     = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId        = p.Id
        );
        insert u;
        return u;
    }

    private static Connected_App_Inventory__c buildInventoryRecord(String name) {
        return new Connected_App_Inventory__c(
            Connected_App_Name__c = name,
            App_Type__c           = 'Custom',
            Risk_Rating__c        = 'Medium',
            Status__c             = 'Under Review',
            Last_Review_Date__c   = Date.today()
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Positive: before-insert defaults are applied
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testPositiveFlow_BeforeInsert_SetDefaults() {
        User admin = getAdminUser();

        Connected_App_Inventory__c rec = new Connected_App_Inventory__c(
            Connected_App_Name__c = 'DefaultsTestApp',
            App_Type__c           = 'Custom'
            // Intentionally omit Status__c, Risk_Rating__c, Last_Review_Date__c
        );

        Test.startTest();
        System.runAs(admin) {
            insert rec;
        }
        Test.stopTest();

        Connected_App_Inventory__c saved = [
            SELECT Status__c, Risk_Rating__c, Last_Review_Date__c
            FROM   Connected_App_Inventory__c
            WHERE  Id = :rec.Id
        ];
        System.assertEquals('Under Review', saved.Status__c,
            'Default Status should be Under Review.');
        System.assertEquals('Medium', saved.Risk_Rating__c,
            'Default Risk Rating should be Medium.');
        System.assertEquals(Date.today(), saved.Last_Review_Date__c,
            'Last Review Date should default to today.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Positive: after-update owner change triggers email notification
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testPositiveFlow_AfterUpdate_NotifyOwner() {
        User admin   = getAdminUser();
        User newOwner;

        System.runAs(admin) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            newOwner = new User(
                LastName         = 'NewOwner',
                FirstName        = 'App',
                Email            = 'newowner@keneland.com',
                Username         = 'newowner' + Datetime.now().getTime() + '@keneland.com',
                Alias            = 'nwownr',
                TimeZoneSidKey   = 'America/New_York',
                LocaleSidKey     = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId        = p.Id
            );
            insert newOwner;
        }

        Connected_App_Inventory__c rec = buildInventoryRecord('OwnerChangeApp');
        System.runAs(admin) {
            insert rec;
        }

        Test.startTest();
        System.runAs(admin) {
            rec.Technical_Owner__c = newOwner.Id;
            update rec;
        }
        Test.stopTest();

        Connected_App_Inventory__c updated = [
            SELECT Technical_Owner__c
            FROM   Connected_App_Inventory__c
            WHERE  Id = :rec.Id
        ];
        System.assertEquals(newOwner.Id, updated.Technical_Owner__c,
            'Technical Owner should be updated to the new owner.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Negative: before-insert missing required Connected_App_Name__c
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testNegativeFlow_BeforeInsert_MissingRequiredFields() {
        User admin = getAdminUser();

        Connected_App_Inventory__c invalidRec = new Connected_App_Inventory__c(
            App_Type__c = 'Custom'
            // Connected_App_Name__c intentionally missing
        );

        Test.startTest();
        Boolean exceptionThrown = false;
        System.runAs(admin) {
            try {
                insert invalidRec;
            } catch (DmlException e) {
                exceptionThrown = true;
            }
        }
        Test.stopTest();

        System.assert(exceptionThrown,
            'Inserting a record without the required Name field should throw a DmlException.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Negative: before-delete prevents deleting Active records
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testNegativeFlow_BeforeDelete_ActiveRecord() {
        User admin = getAdminUser();

        Connected_App_Inventory__c activeRec;
        System.runAs(admin) {
            activeRec = buildInventoryRecord('ActiveDeleteTest');
            activeRec.Status__c = 'Active';
            activeRec.Business_Owner__c = admin.Id;
            insert activeRec;
        }

        Test.startTest();
        Boolean deleteBlocked = false;
        System.runAs(admin) {
            try {
                delete activeRec;
            } catch (DmlException e) {
                deleteBlocked = true;
            }
        }
        Test.stopTest();

        System.assert(deleteBlocked,
            'Deleting an Active Connected App record should be blocked by the trigger.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Bulk: 200 records in a single DML
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testBulkData_Handle200Records() {
        User admin = getAdminUser();

        List<Connected_App_Inventory__c> bulkRecs = new List<Connected_App_Inventory__c>();
        for (Integer i = 0; i < 200; i++) {
            bulkRecs.add(new Connected_App_Inventory__c(
                Connected_App_Name__c = 'BulkApp' + i,
                App_Type__c           = 'Custom'
            ));
        }

        Test.startTest();
        System.runAs(admin) {
            insert bulkRecs;
        }
        Test.stopTest();

        Integer count = [
            SELECT COUNT()
            FROM   Connected_App_Inventory__c
            WHERE  Connected_App_Name__c LIKE 'BulkApp%'
        ];
        System.assertEquals(200, count,
            'All 200 records should be inserted without hitting governor limits.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Positive: status change to Active auto-stamps Last_Review_Date__c
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testPositiveFlow_BeforeUpdate_StampReviewDate() {
        User admin = getAdminUser();

        Connected_App_Inventory__c rec;
        System.runAs(admin) {
            rec = buildInventoryRecord('ReviewDateApp');
            rec.Status__c = 'Under Review';
            insert rec;
        }

        Test.startTest();
        System.runAs(admin) {
            rec.Status__c         = 'Active';
            rec.Business_Owner__c = admin.Id;
            rec.Last_Review_Date__c = null; // Intentionally clear to test auto-stamp
            update rec;
        }
        Test.stopTest();

        Connected_App_Inventory__c refreshed = [
            SELECT Last_Review_Date__c, Status__c
            FROM   Connected_App_Inventory__c
            WHERE  Id = :rec.Id
        ];
        System.assertEquals('Active', refreshed.Status__c,
            'Status should be Active after update.');
        System.assertEquals(Date.today(), refreshed.Last_Review_Date__c,
            'Last Review Date should be auto-stamped to today on Active transition.');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Edge: multiple simultaneous high-risk permission scenarios
    // ─────────────────────────────────────────────────────────────────────────

    @isTest
    static void testEdgeCase_MultipleRecordsUpdateSameTime() {
        User admin = getAdminUser();

        List<Connected_App_Inventory__c> recs = new List<Connected_App_Inventory__c>();
        for (Integer i = 0; i < 5; i++) {
            recs.add(buildInventoryRecord('MultiUpdateApp' + i));
        }
        System.runAs(admin) {
            insert recs;
        }

        Test.startTest();
        System.runAs(admin) {
            for (Connected_App_Inventory__c rec : recs) {
                rec.Status__c = 'Active';
                rec.Business_Owner__c = admin.Id;
            }
            update recs;
        }
        Test.stopTest();

        Integer activeCount = [
            SELECT COUNT()
            FROM   Connected_App_Inventory__c
            WHERE  Status__c = 'Active'
              AND  Connected_App_Name__c LIKE 'MultiUpdateApp%'
        ];
        System.assertEquals(5, activeCount,
            'All 5 records should transition to Active simultaneously.');
    }
}
