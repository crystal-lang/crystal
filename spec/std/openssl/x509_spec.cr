require "spec"
require "openssl"

include OpenSSL::X509

CERT = <<-EOC
-----BEGIN CERTIFICATE-----
MIICszCCAZugAwIBAgIIi210vHbAuNUwDQYJKoZIhvcNAQELBQAwETEPMA0GA1UE
AwwGTXlOYW1lMB4XDTE1MDUxODAwNTA1NloXDTE3MDUxNzAwNTA1NlowETEPMA0G
A1UEAwwGTXlOYW1lMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4TlQ
Xni+2s9CAJ7zHGr5UiLS84YeHIvL72w1urPKXb2mw2wTsu8s44DXCBgp7T/Ex0LR
Q0fpEzFPGL7XhkvWU8zC3xlB1/LQgvAcRu2HBu882xvn3QHqkHHQw9cwmsS3USSa
g2QBgxjVUiGw0ZB6kNMSX4iOk1K6KZBR++SBESUcr+lARNuEiLCHU5INECAIpwI3
CJmUJ2LN6Q/WDNfQhqo9AJ8i2xoX67OYx5MF3ZqxepaRXBI4y6cIkMPf2EoeI5B/
wdVKHwOInXI8yteKZBqKmVP5KZSTrZWp08AhBAzyOiFyEFWRl8+jjfEpmy4WJN6T
du6dSn///Mo1+exORwIDAQABow8wDTALBgNVHQ8EBAMCB4AwDQYJKoZIhvcNAQEL
BQADggEBABMVm3/VW55GvzskSVDg8VxAHisB9LIciTnGmTjuTs8P5B8JMGEVi/w7
RMNM12xkWUUv6A0cwX6WvMfjPo4hMye9M2MHVPZTj1NmB8xxfbJ1FsMxquWuv6O6
CZ/91M3WN3BIP+heYOTok/c4hZUsSYWUxy6e7+G+OC20z4VDz24fcA1L9bzepqqZ
PiijOArukP+ROMnp7iPU4e/FYNi3Nzxc77nhoe3KP6XWzl+wvXUZaxyz6cu1Ca8Y
I31SUlz7tdDg5q7Y14j5JCYLroNeoe53kbGMLNsCkPHltgqtkHadyx4tmz1XX8iq
XAv5m0Q50FMBl0NQ+WWU3+cAVRmOLzE=
-----END CERTIFICATE-----
EOC

describe Certificate do
  it "should be able to load certificate from PEM" do
    certificate = Certificate.from_pem(MemoryIO.new(CERT))
    certificate.subject_name.name.should eq("CN=MyName")
    certificate.fingerprint_hex.should eq("454ed8ec8b5a21f785de57edb5318381bccc98cd")
  end
end

describe Generator do
  it "should be able to generate a new certificate" do
    certificate, pkey =
      Generator.generate do |g|
        g.bitlength = 2048
        g.valid_period = 365 * 2
        g.cn = "MyName"
        g.usage << Generator::KeyUsage::DigitalSignature
      end
    certificate.subject_name.name.should eq("CN=MyName")
    certificate.verify(pkey).should be_true

    loaded_certificate = Certificate.from_pem(MemoryIO.new(certificate.to_pem))
    loaded_certificate.subject_name.name.should eq("CN=MyName")
    loaded_certificate.fingerprint_hex.should eq(certificate.fingerprint_hex)
  end
end
