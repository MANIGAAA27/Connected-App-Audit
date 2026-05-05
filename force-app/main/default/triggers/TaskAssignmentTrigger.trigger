trigger TaskAssignmentTrigger on Task (after insert, after update) {
    if (Trigger.isAfter) {
        if (Trigger.isInsert || Trigger.isUpdate) {
            AI_AssignmentHandler.handleTaskAssignments(Trigger.new, Trigger.isInsert ? null : Trigger.oldMap);
        }
    }
}