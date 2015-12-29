Add-PSSnapin Quest.ActiveRoles.ADManagement
Add-PSSnapin VMware.VimAutomation.Core

function Check-DB {
	Get-MailboxDatabase | Get-MailboxDatabaseCopyStatus
}

function Check-Queue {
	Get-MailboxServer | Get-Queue
}

New-Alias DB Check-DB
New-Alias Q Check-Queue