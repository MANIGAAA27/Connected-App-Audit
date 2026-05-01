/**
 * PermissionAnalysisBatch
 * Batch Apex that scans all active users for high-risk permission combinations
 * across Profiles, Permission Sets, Permission Set Groups, and Muting Permission Sets.
 * Creates Audit_Finding__c records for each violation detected.
 */
public with sharing class PermissionAnalysisBatch implements Database.Batchable<SObject>, Database.Stateful {

    private Id auditRunId;
    private Integer totalFindings;
    private List<String> errorMessages;

    // ─────────────────────────────────────────────────────────────────────────
    // Constructor
    // ─────────────────────────────────────────────────────────────────────────

    public PermissionAnalysisBatch(Id runId) {
        this.auditRunId    = runId;
        this.totalFindings = 0;
        this.errorMessages = new List<String>();
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Batchable interface
    // ─────────────────────────────────────────────────────────────────────────

    public Database.QueryLocator start(Database.BatchableContext bc) {
        if (auditRunId == null) {
            errorMessages.add('Audit Run ID is null — batch aborted.');
            // Return empty result set
            return Database.getQueryLocator(
                'SELECT Id FROM User WHERE IsActive = true AND Id = null'
            );
        }

        // Mark the run as In Progress
        update new Audit_Run__c(
            Id        = auditRunId,
            Status__c = 'In Progress',
            Start_Time__c = Datetime.now()
        );

        return Database.getQueryLocator([
            SELECT Id,
                   Name,
                   Email,
                   ProfileId,
                   Profile.Name,
                   Profile.PermissionsModifyAllData,
                   Profile.PermissionsCustomizeApplication,
                   Profile.PermissionsManageConnectedApps
            FROM   User
            WHERE  IsActive = true
        ]);
    }

    public void execute(Database.BatchableContext bc, List<User> scope) {
        Set<Id> userIds = new Map<Id, User>(scope).keySet();

        // ── Load permission-set assignments (all non-profile PSAs) ────────────
        List<PermissionSetAssignment> psaList = [
            SELECT AssigneeId,
                   PermissionSet.Name,
                   PermissionSet.Type,
                   PermissionSet.IsOwnedByProfile,
                   PermissionSet.PermissionsModifyAllData,
                   PermissionSet.PermissionsCustomizeApplication,
                   PermissionSet.PermissionsManageConnectedApps
            FROM   PermissionSetAssignment
            WHERE  AssigneeId IN :userIds
              AND  PermissionSet.IsOwnedByProfile = false
        ];

        // ── Build userId → PSA list map ───────────────────────────────────────
        Map<Id, List<PermissionSetAssignment>> userToPsaMap =
            new Map<Id, List<PermissionSetAssignment>>();
        for (PermissionSetAssignment psa : psaList) {
            if (!userToPsaMap.containsKey(psa.AssigneeId)) {
                userToPsaMap.put(psa.AssigneeId, new List<PermissionSetAssignment>());
            }
            userToPsaMap.get(psa.AssigneeId).add(psa);
        }

        // ── Load high-risk permission metadata ────────────────────────────────
        List<High_Risk_Permission__mdt> hrpList = [
            SELECT Permission_API_Name__c, Risk_Level__c
            FROM   High_Risk_Permission__mdt
            WHERE  Is_Active__c = true
        ];
        Set<String> highRiskPermNames = new Set<String>();
        for (High_Risk_Permission__mdt hrp : hrpList) {
            highRiskPermNames.add(hrp.Permission_API_Name__c);
        }

        List<Audit_Finding__c> findings = new List<Audit_Finding__c>();

        // ── Evaluate each user ────────────────────────────────────────────────
        for (User u : scope) {
            Boolean profileModifyAll   = u.Profile.PermissionsModifyAllData;
            Boolean profileCustomize   = u.Profile.PermissionsCustomizeApplication;
            Boolean profileManageApps  = u.Profile.PermissionsManageConnectedApps;

            // Aggregate effective permissions across all sources
            Boolean effectiveModifyAll  = profileModifyAll;
            Boolean effectiveCustomize  = profileCustomize;
            Boolean effectiveManageApps = profileManageApps;

            // ── Per-source checks (Profile) ───────────────────────────────────
            findings.addAll(
                evaluateSource(u.Id, 'Profile', u.Profile.Name,
                               profileCustomize, profileModifyAll, profileManageApps)
            );

            // ── Per-source checks (Permission Sets / Groups / Muting) ─────────
            if (userToPsaMap.containsKey(u.Id)) {
                for (PermissionSetAssignment psa : userToPsaMap.get(u.Id)) {
                    Boolean psModifyAll  = psa.PermissionSet.PermissionsModifyAllData;
                    Boolean psCustomize  = psa.PermissionSet.PermissionsCustomizeApplication;
                    Boolean psManageApps = psa.PermissionSet.PermissionsManageConnectedApps;
                    String  sourceType   = resolveSourceType(psa.PermissionSet.Type);

                    // Muting permission sets subtract permissions; skip additive check
                    if (psa.PermissionSet.Type == 'Muting') {
                        effectiveModifyAll  = effectiveModifyAll  && !psModifyAll;
                        effectiveCustomize  = effectiveCustomize  && !psCustomize;
                        effectiveManageApps = effectiveManageApps && !psManageApps;
                        continue;
                    }

                    // Per-source prohibited combination check
                    findings.addAll(
                        evaluateSource(u.Id, sourceType, psa.PermissionSet.Name,
                                       psCustomize, psModifyAll, psManageApps)
                    );

                    // Accumulate effective permissions
                    effectiveModifyAll  = effectiveModifyAll  || psModifyAll;
                    effectiveCustomize  = effectiveCustomize  || psCustomize;
                    effectiveManageApps = effectiveManageApps || psManageApps;
                }
            }

            // ── Cross-source effective-permission check ────────────────────────
            // Only flag cross-source if the combo wasn't already reported in-source
            Boolean comboAlreadyFlagged =
                (profileCustomize && profileModifyAll) ||
                (profileCustomize && profileManageApps);

            if (!comboAlreadyFlagged && userToPsaMap.containsKey(u.Id)) {
                for (PermissionSetAssignment psa : userToPsaMap.get(u.Id)) {
                    if (psa.PermissionSet.Type == 'Muting') continue;
                    if ((psa.PermissionSet.PermissionsCustomizeApplication &&
                         psa.PermissionSet.PermissionsModifyAllData) ||
                        (psa.PermissionSet.PermissionsCustomizeApplication &&
                         psa.PermissionSet.PermissionsManageConnectedApps)) {
                        comboAlreadyFlagged = true;
                        break;
                    }
                }
            }

            if (!comboAlreadyFlagged) {
                if (effectiveCustomize && effectiveModifyAll) {
                    findings.add(buildFinding(u.Id,
                        'Customize Application + Modify All Data (cross-source effective)',
                        'Effective Permissions', u.Name, 'Critical'));
                }
                if (effectiveCustomize && effectiveManageApps) {
                    findings.add(buildFinding(u.Id,
                        'Customize Application + Manage Connected Apps (cross-source effective)',
                        'Effective Permissions', u.Name, 'Critical'));
                }
            }

            // Standalone Modify All Data (any source)
            if (effectiveModifyAll &&
                !findings.isEmpty() == false &&
                !effectiveCustomize && !effectiveManageApps) {
                findings.add(buildFinding(u.Id,
                    'Modify All Data (standalone — no approved exception)',
                    'Effective Permissions', u.Name, 'High'));
            }
        }

        if (!findings.isEmpty()) {
            insert findings;
            totalFindings += findings.size();
        }
    }

    public void finish(Database.BatchableContext bc) {
        String finalStatus  = errorMessages.isEmpty() ? 'Completed' : 'Completed with Errors';
        String errorSummary = String.join(errorMessages, '\n');
        if (errorSummary.length() > 32768) {
            errorSummary = errorSummary.substring(0, 32768);
        }

        update new Audit_Run__c(
            Id              = auditRunId,
            Status__c       = finalStatus,
            End_Time__c     = Datetime.now(),
            Total_Findings__c = totalFindings,
            Error_Message__c  = errorSummary
        );
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    private List<Audit_Finding__c> evaluateSource(
        Id userId,
        String sourceType,
        String sourceName,
        Boolean hasCustomize,
        Boolean hasModifyAll,
        Boolean hasManageApps
    ) {
        List<Audit_Finding__c> sourceFindings = new List<Audit_Finding__c>();

        if (hasCustomize && hasModifyAll) {
            sourceFindings.add(buildFinding(userId,
                'Customize Application + Modify All Data',
                sourceType, sourceName, 'High'));
        }
        if (hasCustomize && hasManageApps) {
            sourceFindings.add(buildFinding(userId,
                'Customize Application + Manage Connected Apps',
                sourceType, sourceName, 'High'));
        }
        if (hasModifyAll && !hasCustomize) {
            sourceFindings.add(buildFinding(userId,
                'Modify All Data (standalone)',
                sourceType, sourceName, 'High'));
        }
        if (hasManageApps && !hasCustomize) {
            sourceFindings.add(buildFinding(userId,
                'Manage Connected Apps (standalone)',
                sourceType, sourceName, 'Medium'));
        }

        return sourceFindings;
    }

    private Audit_Finding__c buildFinding(
        Id userId,
        String permName,
        String source,
        String sourceName,
        String riskLevel
    ) {
        Audit_Finding__c finding = new Audit_Finding__c();
        finding.Audit_Run__c        = auditRunId;
        finding.User__c             = userId;
        finding.Permission_Name__c  = permName;
        finding.Permission_Source__c = source;
        finding.Source_Name__c      = sourceName;
        finding.Risk_Level__c       = riskLevel;
        finding.Status__c           = 'Open';
        return finding;
    }

    private String resolveSourceType(String psType) {
        if (psType == 'Group')   return 'Permission Set Group';
        if (psType == 'Muting')  return 'Muting Permission Set';
        return 'Permission Set';
    }
}
