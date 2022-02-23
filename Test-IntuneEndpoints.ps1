
$endpoints = @(
    "login.microsoftonline.com",
    "officeconfig.msocdn.com",
    "config.office.com",
    "graph.windows.net",
    "enterpriseregistration.windows.net",
    "portal.manage.microsoft.com",
    "m.manage.microsoft.com",
    "wip.mam.manage.microsoft.com",
    "mam.manage.microsoft.com",
    "manage.microsoft.com",
    "euprodimedatapri.azureedge.net",
    "euprodimedatasec.azureedge.net",
    "euprodimedatahotfix.azureedge.net",
    "do.dsp.mp.microsoft.com",
    "dl.delivery.mp.microsoft.com",
    "emdl.ws.microsoft.com",
    "wns.windows.com",
    "notify.live.net",
    "login.microsoftonline.com",
    "login.live.com",
    "events.data.microsoft.com",
    "ztd.dds.microsoft.com",
    "cs.dds.microsoft.com",
    "www.msftconnecttest.com",
    "microsoftaik.azure.net",
    "ekop.intel.com/ekcertservice",
    "ekcert.spserv.microsoft.com/EKCertificate/GetEKCertificate/v1",
    "ftpm.amd.com/pki/aia",
    "go.microsoft.com",
    "activation.sls.microsoft.com",
    "crl.microsoft.com/pki/crl/products/MicProSecSerCA_2007-12-04.crl",
    "validation.sls.microsoft.com",
    "activation-v2.sls.microsoft.com",
    "validation-v2.sls.microsoft.com",
    "displaycatalog.mp.microsoft.com",
    "licensing.mp.microsoft.com",
    "purchase.mp.microsoft.com",
    "displaycatalog.md.mp.microsoft.com",
    "licensing.md.mp.microsoft.com",
    "purchase.md.mp.microsoft.com",
    "officeapps.live.com",
    "online.office.com",
    "office.live.com",
    "cdn.office.net",
    "contentstorage.osi.office.net",
    "onenote.com",
    "cdn.onenote.net"
)

#time.windows.com UDP 123)

foreach ($endpoint in $endpoints) {
    $result80 = Test-NetConnection -ComputerName $endpoint -Port 80
    $result443 = Test-NetConnection -ComputerName $endpoint -Port 443

    if (-Not $result80.TcpTestSucceeded) {
        Write-Host -Object "Failed connection to $($endpoint) on port 80" -ForegroundColor Red
    }
    if (-Not $result443.TcpTestSucceeded) {
        Write-Host -Object "Failed connection to $($endpoint) on port 443" -ForegroundColor Red
    }
    <#if ($result80.TcpTestSucceeded -and $result443.TcpTestSucceeded) {
        Write-Host -Object "$($endpoint) success" -ForegroundColor Green
    }#>
}
