let
  diverofdark = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCz5Mz8hwMB+mmNPB3g8NLUNq5SoWzoXRxOlSDQKpaGcPJCJaemXf3BVMFHdy/6pBnsrsD/aaA80ouJd40cu6jEdwy/9Z6VD65N8feNzV2xcdRoHUdAHyjyICkipX8kBTvhU4RznoGQFhunqwORuAhE4+7pEXyRHd/PUfKreYAXVuMGmh1Cs5WHmNLPje1VBdg4BgL9kSZbCkKlUsAp5KeAzvRHnJaCNAUkARDD4Bjdcm36uyctIg06AEMpun6GcEmMGSLoCwjl8S4SUCYbNbXK4mPmrGKS2Vm+tSbc3VH7JZwynHC8HQcAFiuQcXXM/j7UxWCyr8huvPTKILRIaZQZ";
  users = [ diverofdark ];

  raspi = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIERL96KCXBRNMaS/zherCUsnNN+y23pp9Xse4CBBmkPz";
  alfheimr = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBz6Q0DpnCNOkzAeTzxtyj1haQAg+WGy2ULshkoOAxkZ";
  machines = [ raspi alfheimr ];
in
{
  "wifipassword.age".publicKeys = users ++ machines;
  "k3s-secrets.age".publicKeys = users ++ machines;
}