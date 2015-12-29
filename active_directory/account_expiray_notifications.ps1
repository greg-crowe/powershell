Import-Module ActiveDirectory

$SMTPserver="mail.example.com"

# This is the upper limit for how many days out notifications will be set
$NotificationPeriod = 14

# This is the mailbox from which the messages will appear to originate. If you have A LOT of users this should be something generic / ticketing address
$From = "Your Helpdesk <helpdesk@example.com>"

$LogFile = "c:\temp\account_expiry_notifications.csv"
$Testing = $False

# Enable testing here by uncommenting the next line and modifying your test recipient address
#$Testing = $True
$TestRecipient = "test@example.com"

$Date = Get-Date -format ddMMyyyy
$MaxPasswordAge = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge
$DateStamp = Get-Date -Format yyMMdd

if (-NOT (Test-Path $LogFile))
    {
        New-Item $LogFile -ItemType File
        Add-Content $LogFile "Date,Name,EmailAddress,DaystoExpire,ExpiresOn"
    }

# User filter needs your org's domain name
$UserFilter = {(Enabled -eq "True") -and (PasswordNeverExpires -eq "False") -and (EmailAddress -like '*@example.com')}

$AllUsers = Get-ADUser -Resultsize Unlimited -Filter $UserFilter -Properties Name, PasswordNeverExpires, PasswordExpired, PasswordLastSet, EmailAddress | ?{ $_.PasswordExpired -eq $False }
$Users = $null

# Specify one (or more by cloning and editing the next line) OUs from which to filter users
$Users += $AllUsers | ? {$_.DistinguishedName -match 'OU=Users,DC=example,DC=com'}


$NotifyList = @()

# Loop the users result set and message everyone whose password is expiring within
Foreach ($User in $Users)
    {
        $Name = $User.Name
        $PasswordSetDate = $User.PasswordLastSet
        $EmailAddress = $User.EmailAddress
             # Check for 'Fine Grained Password Policy'
            $PasswordPol = (Get-AduserResultantPasswordPolicy $User)
            if (($PasswordPol) -ne $null) {$MaxPasswordAge = ($PasswordPol).MaxPasswordAge}
        $ExpiresOn = $PasswordSetDate + $MaxPasswordAge
        $DaysUntilExpiration = (New-TimeSpan -Start (Get-Date) -End $Expireson).Days


        if (($DaysUntilExpiration) -ge "1") {
            $MessageDays = "in " + "$DaysUntilExpiration" + " day$(if ($DaysUntilExpiration -eq 1) {''} else {'s'})"
            } else {
            $MessageDays = "today"
            }


        $Subject="Your password will expire $MessageDays"
        $Body = @"
Hi $Name,
<p>
Your AD password expires $MessageDays. Please change your password.
</p>


"@
        if ($Testing) { $EmailAddress = $TestRecipient } 


        $MailArguments = @{
            SMTPServer = $SMTPserver
            From = $From
            To = $EmailAddress
            Subject = $Subject
            Body = $Body
            BodyAsHTML = $True
            Priority = "High"
            }


        if (($DaysUntilExpiration -ge "0") -and ($DaysUntilExpiration -le $NotificationPeriod))
            {
                Add-Content $LogFile "$Date,$Name,$EmailAddress,$DaysUntilExpiration,$ExpiresOn"
                $NotifyItem = New-Object System.Object
                $NotifyItem | Add-Member -type NoteProperty -Name Name -Value $User.Name
                $NotifyItem | Add-Member -type NoteProperty -Name Expiry -Value $ExpiresOn
                $NotifyList += $NotifyItem
                Send-Mailmessage @MailArguments
            }
    
    }

# Do the magic here
Send-MailMessage -SmtpServer $SMTPserver -From $From -To $TestRecipient -Body  "$($NotifyList | Sort-Object Expiry | ConvertTo-Html)" -BodyAsHtml -Subject "Important: your password will expire soon"

if ($error) {$error | out-file "c:\temp\$datestamp.error.txt" }

