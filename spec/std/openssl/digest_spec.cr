require "spec"
require "../src/openssl"

describe OpenSSL::Digest do
  [
    {:md4, "0ac6700c491d70fb8650940b1ca1e4b2"},
    {:md5, "acbd18db4cc2f85cedef654fccc4a4d8"},
    {:mdc2, "5da2a8f36bf237c84fddf81b67bd0afc"},
    {:ripemd160, "42cfa211018ea492fdee45ac637b7972a0ad6873"},
    {:sha, "752678a483e77799a3651face01d064f9ca86779"},
    {:sha1, "0beec7b5ea3f0fdbc95d0dd47f3c5bc275da8a33"},
    {:sha224, "0808f64e60d58979fcb676c96ec938270dea42445aeefcd3a4e6f8db"},
    {:sha256, "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae"},
    {:sha384, "98c11ffdfdd540676b1a137cb1a22b2a70350c9a44171d6b1180c6be5cbb2ee3f79d532c8a1dd9ef2e8e08e752a3babb"},
    {:sha512, "f7fbba6e0636f890e56fbbf3283e524c6fa3204ae298382d624741d0dc6638326e282c41be5e4254d8820772c5518a2c5a8c0c7f7eda19594a7eb539453e1ed7"},
  ].each do |tuple|
    it "should be able to calculate #{tuple[0]}" do
      digest = OpenSSL::Digest.digest(tuple[0])
      digest << "foo"
      digest.hexdigest.should eq(tuple[1])

      digest.class.hexdigest("foo").should eq(tuple[1])
    end
  end
end
