require "spec"
require "random/isaac"

describe "Random::ISAAC" do
  it "generates random numbers as generated official implementation" do
    numbers = [
      0xc9d3bc51, 0x5bc24339, 0x23e22e3a, 0x5659b89a, 0x21c6dcfd, 0x168e10a4, 0x1df755f6, 0x99d3a910,
      0xf48f0656, 0xe9431f57, 0x839c384b, 0x238bac78, 0xd3693e2a, 0x96e06a6f, 0x1358bb9e, 0x6872ff7f,
      0x75f9a391, 0x9d951a6f, 0x4460a8a1, 0x2818c604, 0x459b44fc, 0xe4eeacbf, 0xb13edb9c, 0x38f9a0c4,
      0x9b6c882d, 0x44ddb798, 0x6a02781b, 0x464d8241, 0xb6e89c5b, 0xee627b94, 0x4b5cf183, 0x030800c9,
      0x63e24cba, 0x9582bdaa, 0x8b038c2c, 0x5bcc29d7, 0xab4e8369, 0x7874b242, 0x1302a96d, 0xec44d5cc,
      0x6cc59d03, 0x9abc6857, 0xea100737, 0xc567708f, 0xb25912b4, 0x53899438, 0xb33ba5c0, 0x08d848bc,
      0xe32573ca, 0x1190acf5, 0xd015c2e7, 0xbe2f137f, 0x2f059bb6, 0x82ca6f0a, 0x39172da5, 0x9bcb3a5b,
      0x8288cd54, 0x2f7a6e72, 0x371ac597, 0x3c9c00e1, 0x584ae462, 0x7420bf5e, 0xb3e7eeb3, 0xcb1f301d,
      0x89f7548d, 0x5c758f6e, 0x5e5689f4, 0xfda0ec6b, 0xd080797e, 0xc8ce8e0e, 0x08ed5b1a, 0x75f4dca7,
      0xc03c8d08, 0xad11d474, 0xcb4ee33a, 0x6588dd1e, 0xe71dd73d, 0x25b36d83, 0xc2a014ee, 0x1f1be022,
      0x97748d52, 0xba47b4b2, 0xb5b0f69f, 0x9092902e, 0x8cc370f9, 0xa65b687f, 0xbb8ad147, 0x3c532186,
      0x25ff761b, 0xf507c27c, 0xafb18108, 0x3b8e7ade, 0x3044df96, 0xf5b51be4, 0xb8b3895f, 0x56ad9f82,
      0x13cf0045, 0xadbbcd41, 0xba984c48, 0xac14915f, 0x4dea8a1c, 0x70240f6e, 0x46e5085b, 0x44995e68,
      0xd49a2785, 0xbec21184, 0x33bd3209, 0x28b6c25f, 0x8aaa592c, 0x642844eb, 0xb2a8bf4f, 0xb62c21b4,
      0x1ed94071, 0x5047c204, 0x9966bf98, 0x54d6a1de, 0xd3b08718, 0x602cdd1e, 0x27d3b289, 0xf5284ba7,
      0xe552480e, 0xb4317128, 0xa6a831c7, 0xef98ba77, 0x082e2387, 0xa60f8187, 0x1bdda376, 0xd11b59d2,
      0x0b2adb58, 0x5f07968d, 0x63565555, 0x6eaaa2da, 0x43de6b6d, 0x86d498ff, 0xe3492290, 0x87aa3a05,
      0x4ea8d3b5, 0xbb9fe9a1, 0x798b2222, 0x3e77c27e, 0xd263434e, 0x82d504cb, 0x5936c07b, 0x82b93bcb,
      0x40e1ddc4, 0xfed24c09, 0x5e66d6e5, 0xb3f09f1d, 0x812b901c, 0x99b87e3b, 0x7ac6b7ed, 0x30d63060,
      0x7508dc03, 0xa42248a9, 0xad313fdf, 0x3a4e945c, 0xac875460, 0x0940e817, 0x9f71db1f, 0xed35bebe,
      0x29c77c31, 0x79e42f94, 0xa3dbcd79, 0x40651421, 0xd9af6853, 0x66b9ecc1, 0x9d93f3c4, 0xa38e3003,
      0x181e1ab7, 0xc952f8ef, 0xdfaebb9e, 0x91a50215, 0x95590c72, 0xd2d2db40, 0x7a479242, 0x9ae6f3dc,
      0x6d6ee596, 0xf0ccabd5, 0x50367e9e, 0xaf96bafa, 0xc4940ecd, 0x63a82778, 0xe40950a9, 0xfabf9e2c,
      0xf91450e9, 0x1ad83713, 0x795209f6, 0x9f7d8ca0, 0xc4cd930c, 0x2ac7c086, 0xa24e2dab, 0x8b7a3616,
      0xb691e3ec, 0xf30e7631, 0x3f09c258, 0x4ea46c5a, 0xd799e7d8, 0x75d3fa5d, 0x17966f6c, 0xb9f30b32,
      0xda1e3c67, 0xab3dc36a, 0xd3a47ef3, 0x48301362, 0x0df21a5c, 0x38731862, 0xa8b52636, 0xf4b7ab4f,
      0xb709addd, 0x0642b616, 0x645c68bb, 0x7defde20, 0xc7eb832e, 0xc5d9d39e, 0xc52256e5, 0x992300b4,
      0xc581df99, 0xa642f4aa, 0xd4f0ba87, 0x94b9d830, 0x92c4ced6, 0xa74b776e, 0x87d32645, 0xdab3bd5f,
      0x99f8eec0, 0xe0457735, 0xb44c5c92, 0x95688a53, 0x3856aae8, 0x3352431d, 0x77449906, 0x011d7f76,
      0x936df33e, 0x5de7c346, 0x2f6039f8, 0x05795322, 0xd6b64887, 0x9f812dab, 0x416c484d, 0xc63687a5,
      0xb0658c71, 0x772bfea5, 0x3ed63727, 0xcc03377f, 0x2d658374, 0x40597e84, 0xef62dfaa, 0x3ba989b7,
      0xd1b26dc5, 0xd3a7f5e1, 0xe5de149f, 0x9c26e15a, 0x63477791, 0x3c7a0855, 0xf00990dd, 0xcb673179,

      0x58759924, 0x2be2c273, 0x03165f2e, 0xe4f4832b, 0x88fa93d2, 0xcc096c83, 0xfb713a21, 0x99aa55bd,
      0xeae7f35d, 0xddaf236c, 0xda0552ce, 0xd2fb442f, 0xfd1ac65e, 0xa680c86c, 0x7a9f36c0, 0xa5ccce35,
      0x8060b929, 0xe2a6a2da, 0x68175335, 0x18859b40, 0xd2b4213b, 0x97a896c0, 0x119d3659, 0xbc89d7b1,
      0x8feb1ca4, 0x68329ee6, 0x5881583d, 0xcd58805e, 0x2621ab01, 0xf0b07a6b, 0x88307d30, 0x75b6547d,
      0x40c99197, 0x8916ae7d, 0x7f623b33, 0x951c0396, 0x2bc389d3, 0x80f0a93d, 0xfaa5640a, 0xbd5a6773,
      0x86c411ae, 0x80171a7e, 0xcc27f2ec, 0x6ea7df33, 0x24bd0f91, 0xe5a1e0a9, 0x2f32057e, 0x3cb4da7c,
      0x025b3f1a, 0x4f04f06d, 0xf6629668, 0x59e4708a, 0xf93cb92f, 0xbdefd4be, 0xa305c6cc, 0xd7aa0586,
      0xc6a074a1, 0xfd3e7ab1, 0x5c3fe3a8, 0xec5ad004, 0xe5b2aedd, 0xe4b6e6b7, 0xef7a2144, 0x3f9e2ab2,
      0x9e23140a, 0xa5f2733f, 0x1db7d2ab, 0x365a3698, 0x8d01cc58, 0xf31bf73b, 0xafcba5b3, 0xd2eaf84c,
      0x54a0200d, 0x7df1f1ef, 0x6e6a858c, 0x0cc1c65c, 0xadd26e2d, 0x86e02783, 0x3aa30e3f, 0x221249e9,
      0x0ca77c21, 0x1b4deef6, 0x72d63e5c, 0xdb48a367, 0x0dbc58d3, 0xd611e807, 0x4bb9d5ff, 0x445beeb0,
      0x58326450, 0x91924ae2, 0x4027ff30, 0x5ed0ab34, 0x38580f9d, 0x4124eeac, 0x5ba2bd88, 0xbe7154aa,
      0xb66952bd, 0xe6a08935, 0x115712da, 0xc27c05d0, 0xea230b0e, 0xcc80600a, 0xc670034c, 0x8dbb11bc,
      0x42b780c1, 0x8491adf6, 0xe649f1c5, 0x9d39fc15, 0x63820ed6, 0x60e6a306, 0x38ebf6c4, 0xf537d52c,
      0x98453ad1, 0x6958ce28, 0x91c47f60, 0xc791d92c, 0x9f7a347f, 0xa58743d0, 0x6b6739cf, 0x30bb95b1,
      0x890c0c52, 0x15a8b715, 0x103cfae2, 0x46bb7f76, 0xd86585a4, 0xc1680e03, 0xb1aad2a1, 0xd56f19ad,
      0xffa33b12, 0x6506373d, 0x16096bc8, 0xae81b350, 0x993096a2, 0x41b7a646, 0xf4f4e782, 0x0ba9ef2e,
      0x0a90c635, 0x363b3142, 0x469afd16, 0x747bf4fb, 0xcc4d3f57, 0x343ca09e, 0x849c719d, 0xc26d6463,
      0x3f9309b8, 0xf9d86bb6, 0x9eb17378, 0x41a37a96, 0x8c23612c, 0x7a6a50e7, 0x29c858ff, 0x01d94ceb,
      0xfd154ca7, 0xf36e5b93, 0x41c24179, 0x7e850621, 0x27881f8c, 0xcbb4854e, 0x6c4bb075, 0x7a9b2efd,
      0x30e57d5b, 0x3e21b866, 0x6be35753, 0x756b2486, 0x1e444d31, 0x19a4dc7b, 0xb2539523, 0x1ba56f3c,
      0xa57cfeac, 0x2dca0894, 0x68d2dae4, 0x8eba2481, 0xecb9c405, 0x94bd6ba2, 0x7bb4392c, 0x16907ad2,
      0x253f9a39, 0x10f05c59, 0x76300440, 0xdafe3594, 0x53c2a3bb, 0x6fb3b5a9, 0x6c598880, 0x6292e448,
      0x81a97eb7, 0x31714189, 0x133bdb20, 0xa2438d54, 0x39481d9f, 0x07c72fc3, 0x2fa9698b, 0x6a6d2133,
      0x8594d9b6, 0x71704614, 0x177a0b8e, 0x6e90b22c, 0x87f7aeff, 0x3c561f6d, 0xa923ddbd, 0x73250219,
      0x3738d0d1, 0x9f765c9b, 0xb733529f, 0x215fa15b, 0x77308fef, 0xd1b2ad98, 0xb59441fd, 0x395882d2,
      0x37e8cb59, 0xbbfc6d29, 0x4b860ceb, 0xe884d62a, 0xfcbed672, 0x44752a76, 0xa57a2a4d, 0x635b1a64,
      0x2598ed26, 0x1f437c1d, 0xfb72da0a, 0xb3518deb, 0x79dcd406, 0x9614d1d1, 0x40a94e5a, 0xda4ef12f,
      0xa986e219, 0xccc2276e, 0x7d3565aa, 0xa3e84df3, 0xf85ec416, 0x4647abf3, 0xf38179fd, 0x3aebddd0,
      0x3b7b1612, 0xaaac1068, 0xe6e356e7, 0x0d42ed8e, 0x52802d42, 0xd404fa1f, 0xd02058d1, 0x87089208,
      0xefcd8c83, 0x1580ea86, 0x3fadf252, 0xb136ccae, 0x1b1fe1f2, 0x4b120e96, 0x6721bb2d, 0x37408741,
      0xc808db89, 0x67683003, 0xa432fad5, 0xd296460f, 0x5f7af670, 0x8c1c6a0e, 0x96f7e892, 0x34c2bee1,

      0x82bfb110, 0x1f91280a, 0x3a62acb0, 0x4dd2dde6, 0x5f1bfa9e, 0xe0fa9943, 0x8afe9c4d, 0x7b4ed2eb,
      0xa30c0d49, 0x6a5d63cb, 0x4b8cbd22, 0xfd29c18d, 0x9f1dea21, 0xcece3d8a, 0xa1e74191, 0x63a209df,
      0xac074eee, 0xa68b1bb0, 0xd4d627ab, 0xbe495903, 0x33ceaf65, 0x849a94e3, 0x34ccfa61, 0x5c53d80d,
      0xa1858372, 0x69ef266d, 0xaf68ef08, 0x56453458, 0xfaf982b7, 0xf85a0427, 0x322a55f2, 0x25ae65df,
      0x2d9b56c8, 0x50db1350, 0xc20f1c2e, 0x3af50ad0, 0x45768784, 0xb220d550, 0x2e8a32f6, 0x176afab5,
      0xba64e5bd, 0xb0e70111, 0xce9127d8, 0x725a471a, 0x88b2112d, 0x2392e3d8, 0x7b73526a, 0x7b406495,
      0x07e522a7, 0x96edd53c, 0x417c9383, 0xa3e38188, 0x448c71ec, 0x3b8e482e, 0xd83e8c22, 0xd1e71c06,
      0x91337040, 0x27bac997, 0x1b7bb428, 0x6e92c172, 0xe73118f8, 0x43c8a615, 0x23b7f25c, 0x73905a73,
      0x45c28f39, 0x2824e125, 0x63ce182c, 0x18dcd917, 0x674e35af, 0x2234b403, 0xe68e96b8, 0x3d83a78e,
      0x6f11c547, 0x4522dbfe, 0xfb3cd32e, 0x46d4febb, 0xd5eff693, 0xd0689b05, 0x11eedf6d, 0x5bc2a3b1,
      0x18a45c4f, 0x75c74746, 0xdc1015d2, 0x794843c4, 0x0ac0f8bc, 0xa3378645, 0xc56522d6, 0x2a9679a3,
      0x88498acd, 0xdc23aab2, 0x4b90528c, 0x0f427100, 0x3eac1a62, 0x09416e90, 0x3fbff552, 0xce02dd7a,
      0xc66d9b68, 0x91f4dec5, 0x130d1303, 0x7c2e2487, 0xe770be71, 0xe8e7055c, 0xa7402dbb, 0x0aae257d,
      0x6c5e6e10, 0xa95d3cd7, 0x666e884f, 0x3dc18b81, 0xd3f7b6d7, 0x0fe62b61, 0x0ae725c8, 0xfcffa37c,
      0x500ee6bc, 0x44e82874, 0x3938bd47, 0xd9fddfd5, 0x651cf7d2, 0xb5830c4b, 0x143cc0ac, 0x04f252b7,
      0x1b5e9396, 0x27dcbb2e, 0x832296f6, 0x2f67a163, 0x223a5600, 0x5ed5a24d, 0x633c4ccd, 0x7d91df05,
      0x26bf80e4, 0x97d822b3, 0x27d5967e, 0xf55a625f, 0x932752fe, 0x310f3a4b, 0xc21a3530, 0x4acada1c,
      0xcc29cb9f, 0x1328d6c1, 0x2ae2b1cb, 0x5da94c59, 0xd9b4c606, 0xbaec63d4, 0xfeb899ad, 0xdafae2ba,
      0xde4b5293, 0x37c9aca6, 0xe5a1e7b7, 0x4de7e010, 0x994ce0b5, 0x8c3fb14c, 0xeba0b9b9, 0x1afcb533,
      0xbd7a1946, 0xb7861a44, 0x8232f8d0, 0x91862386, 0xd47a81c2, 0xb73d99ce, 0x16d02747, 0x8a99a038,
      0x69283fb0, 0xf36f12ca, 0x6f6f98d5, 0xaf374358, 0x3cff4879, 0xd832caeb, 0x3fe70258, 0xec27aa77,
      0x92c18b79, 0xe2ab8c22, 0x2a614806, 0x294b0402, 0x33568196, 0xb98cd722, 0xdfe675a9, 0x1ce11ef9,
      0xc607374c, 0x38f2cd25, 0xddb6c8ae, 0x79a8d47c, 0xae7de4ad, 0x6f4fec68, 0x0f8eb3f7, 0x096794a2,
      0x957962f9, 0x146383ff, 0xc1a6caf5, 0x2959dd33, 0x9f365615, 0xee8a6df8, 0x75424149, 0x247facf0,
      0x8ab708c3, 0x5d01ef1a, 0xd53bc193, 0xd47a15d8, 0xba6e2ac2, 0x5e2dbd75, 0x7e77d88d, 0xd8ec6f06,
      0xf49bcc85, 0x9c20c879, 0x68335c41, 0xadf8cb04, 0xc96c3a61, 0x82116d16, 0xb94b3371, 0xe7a54a30,
      0x3b4f850a, 0x87ab0f70, 0x653c12f3, 0x5a3fa796, 0xe4d21db0, 0xd900acd2, 0x9d368af7, 0x3a6439fd,
      0xa0bfd498, 0x72e18ecf, 0x3f503e27, 0x573d1033, 0x4b2aa4de, 0x4ec87c39, 0x341ab923, 0xf878ea12,
      0xbf660952, 0xbe7efdc0, 0xe285d42c, 0x6fab666b, 0xefcd9fc2, 0xb173ca19, 0x5872df57, 0x03c045ee,
      0x6f4fa2a9, 0xe6af1827, 0x8536fcbb, 0x691d4ea5, 0x3223f217, 0x678ce439, 0x9a19d63f, 0x7c64d694,
      0x2ca3ccfe, 0x8e1e5565, 0x56d7c18b, 0xb00d300e, 0x0b716925, 0xafb7f887, 0xf5102231, 0xf2799846,
      0x1983ee20, 0xbfec746b, 0x6ddbaada, 0x4d769622, 0xe93dea27, 0x690fbdec, 0xbced48ce, 0x276a499e,

      0xbf093124, 0x23838afa, 0x3f5c5d8b, 0xca56604f, 0x2700fdb7, 0xf4c740ed, 0x66aaadf4, 0x51e04296,
      0x7b32efdd, 0x3a0ad2c8, 0x5242b4bc, 0x48696e9b, 0xfaacccf4, 0xb4a3c7fe, 0x6bbda953, 0x3da076e6,
      0xe7561b1b, 0x38709d67, 0x66f7a62f, 0xd56018be, 0xe8060fd2, 0x1c916d7f, 0x68b6c825, 0x1a8b1f5c,
      0xb19b41f8, 0x382d6a79, 0xc663c584, 0x12c7c27f, 0x421d940a, 0xe898845d, 0x73765c18, 0xd5cb7860,
      0xbfe91037, 0x89cedb70, 0xd4377332, 0x9c4a7921, 0x5decd505, 0x95383a09, 0x06b1bb68, 0x9d8ce838,
      0xe7c17b37, 0x0d53b7f3, 0x6744a32e, 0x06d730c4, 0x540b86f2, 0x525d02f1, 0x09b33d66, 0x9ae35843,
      0x7e158d43, 0x69308bb3, 0xa796ccc9, 0x7d6f1f9e, 0x08e0b6fe, 0x06a26f58, 0xa4451e55, 0xdd51ff7e,
      0x03976dac, 0x8d7d65be, 0x94bba358, 0x08eccc30, 0x417c2afd, 0xb5994b19, 0xecea3f75, 0x90a068dd,
      0x947a43ca, 0x6c946efc, 0x7c639e05, 0x9e8cc79b, 0x969020e9, 0xd90c4bcc, 0x6d86ab67, 0xb0ac8cae,
      0xeadf5da8, 0x82261e03, 0x0b8d0239, 0x3796f6a1, 0x75975ebd, 0x9e770049, 0xc7a0c2f9, 0xc88f8227,
      0x3fc2846f, 0xb733d3e8, 0x66a4d3f5, 0x1b972522, 0x84f85127, 0x630db5a0, 0xfb0df03c, 0x246352ba,
      0xebcd2c3c, 0x04d71c76, 0x451ff5d0, 0xa24e4936, 0x63767436, 0xfea963af, 0x0fee93aa, 0x12b1392e,
      0xc658d0b3, 0x8d91d5d0, 0x389f9550, 0xa8fdc2e6, 0x6173acdd, 0x05b4c3eb, 0x1dc59f66, 0x933c2626,
      0x39d8cb9c, 0x58530135, 0xae81570e, 0x06b28d9f, 0x824a7eda, 0x95dc52bb, 0x7fd2a088, 0x836e4aaa,
      0xa3faba55, 0x4b22de53, 0x053e74f0, 0x66f33bfa, 0x892e58fb, 0xd9e6197d, 0x8986c877, 0xf754b340,
      0xdfed5066, 0xca6d31d0, 0xfdab4f34, 0x96f73339, 0xfa94f181, 0x3829c769, 0x200975d2, 0x556c5516,
      0xe69d214c, 0x1b2f377d, 0xca3043ee, 0x9a0650c9, 0xe4744d6e, 0x82c3b11d, 0x83da8b3e, 0xc888cec9,
      0xb744dc12, 0xd59db035, 0x13323e1d, 0xc2750391, 0x3cf5e0a8, 0xa24e4f2c, 0xdd76c0e3, 0xcef10bc8,
      0xe09f8ad3, 0xdef56528, 0xddf7555d, 0xe5a60292, 0x43e0fef5, 0xce5e3d76, 0x4d85e8cc, 0x43d50543,
      0x5614f236, 0xb49730da, 0x8b0a119c, 0x7fa45199, 0x0f4b844d, 0xb07d5fcb, 0xc7e32e83, 0xe5e045db,
      0xa5c18a5a, 0x9433dea9, 0xe374ac1a, 0xcfe5ba5f, 0xea249655, 0x5dc86bf0, 0x2db637ce, 0x76b12992,
      0x43efac8e, 0xc09da4b1, 0x0d866d07, 0x70df34a9, 0x6900cf8a, 0x7f86895d, 0x7baea9dc, 0x76230ff3,
      0x6e57c6bf, 0x6d900ec4, 0x82f04343, 0x70c19cc1, 0x7aedf1f9, 0xf1d50e4e, 0x3218b1d3, 0x156777a7,
      0xc668e59f, 0x59b77c65, 0x37e6c832, 0xa6d25dd2, 0xd1d8dfef, 0x1a566e2e, 0x662937ff, 0x40256e65,
      0xbca3cab0, 0x022837ed, 0x31bba0bd, 0x1cccd256, 0x887b4889, 0xa0c7f7ee, 0x4ec535a8, 0x641b2e12,
      0x65f017a6, 0xaab4c47e, 0x2559ac73, 0xf31260b3, 0x9050014a, 0xfd52848e, 0x2e0ddbb3, 0x40edae6c,
      0x62f498b4, 0xaeee2287, 0x10a5717d, 0xae9011b9, 0x088328ef, 0xa207177f, 0x2bd06251, 0x9612528e,
      0x238a6b79, 0xfb7331fe, 0x605afd54, 0x7ce1474e, 0x9e8a5892, 0x51edec16, 0x48c80b8c, 0x93fef6d3,
      0x70318b34, 0xaaa51ec0, 0x03797400, 0xf56c21f3, 0x6ccac30d, 0xe05f9da9, 0xa4f9a714, 0xbda709bb,
      0x75ca2538, 0x4b2cf037, 0xb50e8e47, 0x5adc1d66, 0xb61057f9, 0x6092a2d8, 0x0facf24a, 0x814e5469,
      0x5a254102, 0x808a5132, 0x459c59d1, 0x084b7a84, 0xd1f76be9, 0x9e0da4f6, 0xaca93892, 0xe4273720,
      0x17cf3431, 0x485e6422, 0x90cf5794, 0x8be8e508, 0x59867098, 0xd6158c8f, 0xacead5ae, 0x89b82d35,

      0x85f3a271, 0x33e29bcc, 0x19cbbd7c, 0x270f8bee, 0xbdd7a6f7, 0xa4cd6d85, 0xd041f8c9, 0x4298ed12,
      0xff115237, 0x73051a2c, 0x0f171a8d, 0x95c41c72, 0x4ea9f45f, 0x9d8353d5, 0x05edcd5f, 0xd9642d8d,
      0x2f3ee4f6, 0x041d823c, 0x75f4dca8, 0x6fe27698, 0x5482c748, 0xff74c84b, 0xfd0b15f2, 0x7293ffe0,
      0xb2f8fe1b, 0x5b7e05b1, 0x52099c24, 0xc7d7f373, 0x6a4f4d3f, 0x587c1389, 0x0e10b7e9, 0x4b46d738,
      0xd40643e8, 0x9125622c, 0x23797663, 0xbb8ed692, 0xac7bf97b, 0xe653a559, 0xc7fdb799, 0xd0d8eff5,
      0x4f6aa37c, 0xc257bd62, 0xf4fc4c67, 0xe0134615, 0x31abc8ab, 0xf1f40499, 0x6e0c379e, 0xde0146ec,
      0x5f43eb0a, 0x5d711c27, 0xc6226a16, 0xfa9a6d66, 0x1e4420f4, 0xd257fc82, 0xbf8ff660, 0x582da380,
      0x458d55a7, 0xba7e3bf6, 0x558019f8, 0xb610fc74, 0x3799f1e9, 0x7483519a, 0x803afc7d, 0x07db3fc7,
      0x8236b726, 0xedfbb74e, 0x52eb0bdd, 0xea642027, 0x248f85f2, 0x0c582c49, 0x82312222, 0x9f2ff69d,
      0x2bec2a0e, 0x2daf3dd2, 0x679e9b7a, 0xeb35ae42, 0x185697ea, 0x393d0939, 0x5a5abc32, 0x4ac3d0f6,
      0x77878265, 0xcc9bb851, 0x383cc75b, 0xb15d4035, 0xe2ededb8, 0x302855b3, 0x904061bb, 0x482e22c7,
      0x71cbd2c7, 0xa9356aba, 0xf01d9bdc, 0xf2c123b8, 0x112337a9, 0xd44ba682, 0x498d6443, 0x07e64438,
      0x1f5c9651, 0xb02a7f08, 0x8801a6b7, 0x76cec13d, 0x89306cfd, 0x127cabba, 0xf7a3f316, 0xcca8ffb7,
      0x61d1af61, 0xabcc5d41, 0xee954691, 0x6877dd8e, 0x34120970, 0x47dbdda4, 0x802ce9a5, 0x904bfab9,
      0x3165fbe2, 0x35e94c9e, 0xe7e884e7, 0x18388950, 0x5dc990ae, 0x86b2e2eb, 0x5d8b4fe8, 0xee782264,
      0x53b3a6e2, 0xc38be31f, 0x6b9a8eb6, 0x6a5bab4c, 0xc88f8e96, 0x3cc2a563, 0x70311ed4, 0xae4e33f4,
      0xa62808b8, 0x6df5280d, 0x8694818e, 0x96aff342, 0x9aaeddb4, 0x74b680e7, 0x7ac429fa, 0x9d8ed6d0,
      0x94267aa2, 0x5180bb7c, 0xd2af1ffa, 0xb4be9992, 0xb6fa5e13, 0x72ce329f, 0xa5515829, 0xa347b435,
      0xa4b1f92d, 0x274f4276, 0x6a29e239, 0x9cbbc43d, 0x8165727b, 0x4edcfa5c, 0x9bef5bad, 0xf1af9a5b,
      0x2d64747d, 0x95554575, 0x5d09c903, 0x01c5d493, 0xf3b80fca, 0xba85b202, 0x8a73bbe5, 0xfd84501f,
      0x52ce6867, 0x34c43428, 0xce8025f6, 0xa5df63ae, 0xdd8b2f3b, 0x7a830956, 0x1243804c, 0xbd046900,
      0xfc796d9f, 0x32a4a0c7, 0x5e2d9837, 0xaf7143f1, 0xf2e7a6a0, 0x48cfb61b, 0xcbe0e7f1, 0xa489305b,
      0xa748c9cf, 0x021fe513, 0xce10ca3f, 0x09774f22, 0xd364fd26, 0x7db83366, 0x7a28fed4, 0x06e727e8,
      0x20188c5d, 0x6b85a86d, 0x60c2e299, 0x7fef9ea7, 0x1ba5fad4, 0xd1a21434, 0xf5271e9d, 0xc1d25786,
      0x7a695f45, 0x9bd51a87, 0x477bf859, 0x7d6956bb, 0x89dc17c9, 0xca9ff278, 0x5c875bf3, 0x3a3a604b,
      0x122cd226, 0x8d9fac92, 0x93118c5f, 0x45df161c, 0xf8ad087f, 0x9c935597, 0xe5decde2, 0x12cee2b3,
      0xcaafd5ed, 0x76fd4a54, 0xb31fde7d, 0xa7a37ad9, 0xbce43857, 0xa04a5d0c, 0xf507d699, 0x470890a2,
      0x459c9411, 0x0bf685f3, 0xb642bc2d, 0xceff08e8, 0xd323b228, 0x456f8c5b, 0x61c77e99, 0x50451742,
      0xec37b849, 0x818a055d, 0xef4c354f, 0x507a6abc, 0x156cf8c1, 0x63c3986a, 0xdf988273, 0x5768018a,
      0x6be28478, 0x9cba4cb7, 0x9572d2d2, 0x794133f1, 0xc28bd648, 0x26302b75, 0xfddf9755, 0x005f339a,
      0xcffd2e5f, 0xc4d8a62e, 0x9b6f3331, 0x4420fbc9, 0x63bd0dfc, 0x5da9e6f2, 0x50386f62, 0x01dccaa5,
      0xc2878f8f, 0x78808e3a, 0xb606ec22, 0x489dee71, 0xdcdfad1e, 0x56573e6c, 0x96bf86b2, 0x85a3e1e0,

      0xd7e500c8, 0xb1b710bf, 0x14014a2f, 0x6dcb205c, 0x84760814, 0xff4c0b6a, 0xc6fc0d95, 0xd2e37fec,
      0x947d7e29, 0x87034305, 0xcbd2e40b, 0x9ed31426, 0x65795f67, 0x6d886463, 0x24ca5721, 0xa189961c,
      0x25965bbb, 0x449f5518, 0x69ab124c, 0x5e92550d, 0xfa6cd0b5, 0xa09bd53c, 0x061c4f21, 0xdd0787ed,
      0x2badf5b5, 0xb1ee8404, 0xc9b139bd, 0x446b17f0, 0xd3a8ad77, 0x00db18ba, 0xd99a1fc5, 0xc88a2589,
      0x3682fbe0, 0x3906800d, 0x330390d9, 0x3a24309f, 0x1e15d59f, 0x112a3945, 0x2655bf38, 0x662f145c,
      0xa08091ba, 0x210c710a, 0x66ba1e76, 0xc135991b, 0x7c11e074, 0x245fdf71, 0x41986e27, 0x7308bc40,
      0x1eed7462, 0xac6861ef, 0x0c1f47e1, 0xf2c9451d, 0x4b077bb1, 0x7cdf31c3, 0x09dfbe0c, 0x4db2d75c,
      0x50483fa7, 0x0c402cbc, 0xa10fbe9b, 0xffeadf92, 0x038cd732, 0x893d954d, 0xa027cca5, 0xb4086433,
      0xf7c1c735, 0x6a1e4a89, 0x0d63555f, 0x7b8f64ee, 0x624eefaa, 0xcde7dc5b, 0xc6ac2f05, 0xeca4dd48,
      0x08c15349, 0xace3a116, 0x6d1c7182, 0x69617cc9, 0xadbad9cd, 0x624b955c, 0xef725d07, 0x216c9609,
      0xac70f55e, 0x10851c19, 0x3768e0b7, 0xb0857be9, 0xb1e8a514, 0x3c8f9c61, 0x450b999a, 0xba3f623a,
      0xbf3db9c1, 0xa87e5b1a, 0xe8edf426, 0x6b1e1e07, 0x47abb2ee, 0x91eb245d, 0x94ffce4c, 0x0cd6f90b,
      0x51bff8ba, 0x6e169820, 0xcd530596, 0xd7666735, 0xb5338e62, 0xcd412881, 0xd235455e, 0xba0e2b24,
      0x16cdcbe5, 0x51a4112b, 0xaea5e49b, 0x4717e79c, 0x1ba26991, 0x0f968182, 0x5e575fd5, 0xe9ebeb48,
      0xe3043134, 0x1cc2971d, 0xde163e51, 0x25a0f7dc, 0xa6243182, 0xae7d8d99, 0x4bc62e48, 0x6c6820df,
      0xed387c95, 0x175a8e05, 0x3e6c405d, 0x46be9398, 0x88f25b5d, 0xf1a0689a, 0x185bc685, 0xc0ca1341,
      0xd4f58df4, 0xaf545c04, 0x9858ebbc, 0xdcdba061, 0x1e5d3c23, 0xa2a9bdc6, 0xa9dbaf2e, 0xfdc145ca,
      0x9aa1a235, 0x3294f226, 0xd41be2d0, 0x12183332, 0xa85a973c, 0xa6f2ef84, 0xd41672d2, 0x3456ab6a,
      0x0ea7dab3, 0xdad9a232, 0xeabf0fd5, 0xdf97da1b, 0x1c253238, 0xd3f63462, 0xbff10852, 0x25553329,
      0xb7e83ce4, 0xd88ee43e, 0xba1e1ec3, 0x735b85c7, 0x3827618e, 0xfd753d4a, 0x3f69630a, 0xb2098f0b,
      0x3dc18f64, 0x32535ead, 0xcd8460e2, 0xa3e1b570, 0xff36a508, 0x237f4641, 0xa11151ed, 0x6a25a236,
      0xf1c46fbf, 0x2cdb30d8, 0x4aa22acc, 0x95d471fe, 0x43ecab6f, 0x54944166, 0xa140cb3e, 0x852957ec,
      0x4b4646e0, 0x6ecd5ddd, 0x395f8ab5, 0x590cff23, 0x5a7c4318, 0xd9f5c6ca, 0x2032b12d, 0xe3283255,
      0xbe329b88, 0x2ff64352, 0xf3efb86e, 0x5e73c4e5, 0x549479c0, 0x0ea61894, 0xf1db0250, 0x5050d378,
      0x3b006062, 0xce0ecdd0, 0x134dab3d, 0x2556cc2e, 0xd78d5278, 0xa6fc08ab, 0x999f01bb, 0x3c31d252,
      0x85b119d8, 0x31088dcb, 0xd474aab7, 0x3d774127, 0x17f19843, 0x5492aa08, 0xbfb72b87, 0x0076f366,
      0x49c6bf28, 0xa0454cfd, 0x07b18806, 0xeae3fc26, 0x00cdf7b0, 0xe2a1ac66, 0x04e489f4, 0xdbf83b34,
      0x97806e32, 0x34dbe9d4, 0x3838f555, 0xf19d40c1, 0x63290196, 0x4d72d76d, 0xc4e2ded6, 0x69bcdafc,
      0xce6a8863, 0x47cb72af, 0x861f07c8, 0xe1f201ef, 0xd2c59529, 0xffeca87c, 0xf4f2c66b, 0x15560271,
      0xfc01981f, 0x54374c06, 0x29888b52, 0x80ecb175, 0x978ebba6, 0xc1625604, 0x2a947eef, 0x99114020,
      0x3ed96c92, 0x29b05341, 0x4b117e1d, 0x5d8ede98, 0x24fe195d, 0xcc59369e, 0x26d547a7, 0x336ca792,
      0xa4951c6f, 0x05ca60b4, 0xe79ba4c4, 0x1977c433, 0xb74b6120, 0x27ef2699, 0xcbb472a3, 0x2e284181,

      0x95670ef0, 0x966d7b3b, 0x773a7d01, 0x9c9446b8, 0x33418f0b, 0x0fd8ac87, 0x6bbe0fd1, 0x459d4e8a,
      0xe0f48ceb, 0x39c8a071, 0x492b0385, 0xdc2d8106, 0x0d640a49, 0x0e488619, 0x0334a66d, 0x7a1fd6cf,
      0x2de4ec65, 0x43cb3c36, 0xd0cb9f5d, 0xc9447608, 0x4aa45e43, 0xd36979f3, 0x90ab19c1, 0xa17b3710,
      0xcfc9ca96, 0xecfca25d, 0xf6b4675c, 0x358840f9, 0xc2438e95, 0x2ba4c297, 0xc031157d, 0xcccbab77,
      0x931e672d, 0x032b1544, 0x87493d48, 0x115914e4, 0xb3cac92d, 0x36ea3f94, 0x79befa66, 0xf6445c4e,
      0x0ac194b0, 0x17aedf31, 0xf9abc1bf, 0x461f440a, 0xed0ea9d7, 0x0804b4d4, 0x15963a7a, 0xeb5d6dcd,
      0x469cd45d, 0x1a04df48, 0x5c9c5096, 0xef2cbec2, 0x4f015e16, 0x89e9e7df, 0x789f59df, 0x4dfd7e25,
      0xd80fdc9d, 0x9ea31b0e, 0xeaa1bcc4, 0x55199a64, 0x0ffe2196, 0xca4f0c73, 0xf41bf7d2, 0xfa3c594c,
      0xd42300d3, 0x8ce4032f, 0xa0a1b50c, 0x58c0fa2a, 0x5e6c0bf3, 0xaa202af8, 0x788902c8, 0xbc9fc92c,
      0xa46d3a64, 0xba0ee3de, 0x2cb98355, 0x48212242, 0x3207e644, 0x58d8754c, 0xbf85197b, 0xca4e1206,
      0x5db644c0, 0xc4537c27, 0x6eb18644, 0xe1d4d97e, 0x978868b1, 0x44853c93, 0x01627bb5, 0x78d648b7,
      0x88019cc3, 0x7f90b9a5, 0xfe10a325, 0xeebeaac2, 0xd1059821, 0x19a6db47, 0x709ef533, 0x0a91b078,
      0xb9088308, 0x41025bb8, 0x55629de3, 0xe6829e3d, 0x66a88813, 0xf49b085d, 0x8007ae69, 0xf89012b0,
      0x568ad64b, 0xef7c5836, 0x98b98e9f, 0xe2493494, 0x3fe71fe3, 0x8d9eafa5, 0x05c751a1, 0x076a0060,
      0xf26a46f9, 0xe02ae45b, 0xcd778771, 0x176378e6, 0xea4c1fd2, 0x38b6812e, 0x9ef3c3ea, 0xd36fb051,
      0xa659a750, 0x04a5e106, 0xe3354c3f, 0x091e149f, 0x50551101, 0x18d2fadf, 0x256a2666, 0x4be6ec5c,
      0x9618a20c, 0xf013c1d8, 0x17935af2, 0xc8bc45e8, 0xad8c9f0b, 0xff98790a, 0x123e2e5b, 0xc3a3ce26,
      0x2b40d93a, 0x62069e01, 0x874835cc, 0xa75c4a18, 0x142a8452, 0xed02ca3a, 0xd6261ceb, 0xf2ee3912,
      0x190172b4, 0x647f7a4d, 0x08486967, 0xe88498f5, 0x8f05debe, 0x61a9d1c3, 0x1cc81029, 0xa241407d,
      0xf264e0ba, 0x53b8c4a5, 0xee794fa3, 0x2a2c5298, 0x9b102fea, 0x7f14fcd4, 0x2ab75348, 0x113d6caa,
      0xfe748b44, 0xb7b04fea, 0x14397082, 0x8c624a5d, 0x308a1b08, 0xc5e21f5c, 0x0bad41da, 0xf700fb15,
      0xb6c6d022, 0x2703957d, 0x7cfba9c9, 0xf2f4c413, 0x2da9341a, 0x688877ca, 0xfd8552a3, 0x1c322698,
      0xfe509b1c, 0x42cfa85b, 0x97e8d290, 0x3f68698b, 0x2dd551dc, 0x5422bfcf, 0x0ea7242c, 0xeb2a57ba,
      0xbe4b6aac, 0x4d4ff5b9, 0xc8517763, 0x1455a465, 0x85e421b9, 0xffb407f0, 0xf943c9c7, 0xac6bea3c,
      0x85173cd4, 0xccef5de3, 0x322dfdd8, 0x029975a1, 0x6dc9053b, 0xbf6a06f1, 0xc96e6205, 0x5e3f2e43,
      0x98e031e8, 0x8783f11c, 0x91e08345, 0x09b3172b, 0x40c4a9e7, 0x4e200b1e, 0xf052be0c, 0xb3996e12,
      0xae58176f, 0x0d5ce9f5, 0x498c1603, 0xfc9e2498, 0x955b974d, 0x0ddbd843, 0xc9f1c6d7, 0x321ba8fa,
      0x4a1be0d9, 0x81ce91e6, 0x43d35f57, 0x3dbb7042, 0x76dbf18c, 0x9b8fc29c, 0x7ba93a93, 0x7bd1e93a,
      0xe58ec417, 0xb5fff41e, 0x5f1d2df7, 0x051bd3a1, 0x2293e9c3, 0xdbfc52a4, 0xa13b3b49, 0xcc622596,
      0x94ac3b7c, 0xad1f0613, 0x78775b92, 0xd095715d, 0x9db05bd8, 0x23d90a52, 0x329e0206, 0xadcde607,
      0x5de3cf48, 0x552c1a6c, 0x51d68fe1, 0x33bb3178, 0xfa8337b3, 0x3ce33684, 0x16795e6b, 0x595c2668,
      0x7a80a22c, 0x257f1b50, 0x70a49552, 0xaa4bd52a, 0x62769811, 0x316bf5a7, 0x6e3b7298, 0x18e6d130,

      0xc85f8cd0, 0x55bb5c19, 0xb35a8372, 0x8aedb363, 0xdd1f2aba, 0x870a0079, 0x8991b4fa, 0x97870061,
      0x4145c192, 0x0e214b78, 0x7c7adbc2, 0x3568cbc7, 0x3401d176, 0x960e13cb, 0xccc5b5c3, 0x1b37cce4,
      0xba34998e, 0x7cf1c415, 0x850d9360, 0x893bfec0, 0x100203b5, 0x6ea5169c, 0x8d1d9bc7, 0xf54af568,
      0x0d897530, 0xdf0a9502, 0x2744a96c, 0x152681c1, 0x9505c01d, 0xb05a4dcc, 0xa720af3f, 0x3b8e0bcd,
      0x8c995fda, 0x227360cf, 0x7dfda437, 0x695547ac, 0xd54592a4, 0x2b21187a, 0xbab355df, 0xd13337e6,
      0xade21480, 0x27e9a890, 0x6d1c139c, 0x48c1d794, 0x2f84b190, 0xa30db3d3, 0x43fcb2e2, 0xdee19a7d,
      0x72dcdab8, 0x2b60180c, 0x5ec131a3, 0xb7a98701, 0x0dcf8888, 0x0e51f081, 0x6b35411d, 0x1ec8cf9d,
      0x5d30ba25, 0x70eb86b9, 0xdcd3067e, 0x5038a362, 0x4372ba7f, 0x519acd12, 0x1a957ec1, 0xed3be91b,
      0x3e0af349, 0x7217a72e, 0xd2448e74, 0xc506c024, 0xac823e92, 0x40c3cc6b, 0x24494058, 0xce6d5a7f,
      0x1b49dba7, 0x585c0ca6, 0xd7ad8721, 0x1755a8a0, 0x2e84a31f, 0xc62a76f9, 0x867578d1, 0x216967e9,
      0xf9736f4c, 0xd0438060, 0x9771e768, 0x57b56966, 0xe8b0685a, 0xa4e3bbc4, 0xca385706, 0xfd42c326,
      0xf8278dd0, 0x152f7425, 0x435ea0c3, 0x1358f804, 0xe344b49c, 0xc2c2c265, 0xedb955e1, 0xe243a719,
      0xaf79a012, 0xb28cdb93, 0x2738bcf4, 0x141e83d7, 0x85075da4, 0x967c380f, 0xa98d5846, 0x09900649,
      0x3a59755a, 0xfad73306, 0xe3d1b112, 0x54d1cf2f, 0x7d8d8991, 0x56281574, 0x7d3b00f0, 0xc99b06f4,
      0xa444dd51, 0x8e59fae9, 0x0a0e076f, 0xf5199ccb, 0xd4f27f02, 0x79e5be6f, 0xd3db7857, 0xe242c216,
      0x31250c93, 0xd1b46a66, 0x1cba290c, 0x9850c30e, 0xbfefa0c7, 0x61f3e260, 0x60df83c7, 0x0b04e4c2,
      0xafc1dd96, 0xead61518, 0x816f41e2, 0xaa957f49, 0xfc72605b, 0xc51508a1, 0x9712df82, 0x09c2f721,
      0x35d0ba5a, 0x06537dd9, 0xa86bf74b, 0x1a89c8e1, 0x82fe165d, 0xd42f920a, 0x2a0b13dc, 0xbd926f61,
      0xd9b4680d, 0x364e43b9, 0xcc51c9e5, 0xbba59f71, 0xbeb2e378, 0x95e3d022, 0x3d6320e9, 0xb21a2508,
      0x5d3e1533, 0x81d5fd42, 0xf9fda71e, 0x1fb91b2a, 0xf733898b, 0x15dfaf9b, 0xdcce2668, 0xecacaeff,
      0xc3bd0c52, 0x193e8d4d, 0xd77dfa27, 0xa2110dee, 0x7323ea1a, 0xfd7c210c, 0x767329bd, 0xef7f9ab1,
      0xe4aa8eee, 0x35b9d7c9, 0xd0c9b92d, 0x9cbcee13, 0xe5de0bd0, 0xfcc3ed47, 0x6ee9f03f, 0xdea97483,
      0x6212a2d4, 0x909f4e5c, 0x35a3bd49, 0x60fd5a28, 0x6d7f806b, 0x118981b7, 0x03b86a2d, 0x7cb2cdd1,
      0x40cc7957, 0x677e0154, 0xd061a377, 0x97e3e18e, 0x1843e4b0, 0xeeeddc76, 0x75801eac, 0xebd3674c,
      0xa8e9304b, 0x1698d0ef, 0xdeb4956e, 0xac9bca76, 0x6cd59737, 0x9e187ad3, 0x05d830f3, 0xb41558a4,
      0xdead3b3c, 0x97bb020f, 0xbed2e29e, 0x82e36d9b, 0x2ee33d31, 0xfd2cfcb8, 0x72d274b7, 0x18460d5c,
      0xca37fa01, 0x7cae93bc, 0xabe70b1b, 0x069cf149, 0xd8296b94, 0x3d4c000a, 0x866cd300, 0x49bd7d07,
      0x59674a55, 0x9020388a, 0x486c54d0, 0x6509ea68, 0xccd4efb9, 0x0b3a7b1a, 0x2a4fb991, 0xd71a571d,
      0xc7acd10e, 0x945ed65d, 0x4f01036a, 0x0f74648e, 0xb1b8a2a0, 0x338f0582, 0xf538dad9, 0x4f8cfaf3,
      0x654bac01, 0x85d42b72, 0x0235ee54, 0x6aa57e45, 0xd3019482, 0xf710a9d3, 0x15f595f4, 0xe62cb2a5,
      0xf23c9621, 0x02f326b9, 0x2b91b5c1, 0xdf661931, 0xf84051e6, 0x73ef77d9, 0x959f6fac, 0xe9ba3125,
      0x35debf70, 0xa845be57, 0x3876135a, 0xd37ede86, 0x04f737e2, 0x7f23a9d0, 0xa4eaa6fa, 0xeab12d7a,

      0xf3abadec, 0xbb13d480, 0xc20ffa91, 0x2f6a8f45, 0x877a094c, 0x8d1bab36, 0x063a2470, 0x5d651277,
      0x448b9f2f, 0x9662bacc, 0x2a2e3487, 0xc109e925, 0xddff1e32, 0x3cdadf7e, 0xe1368518, 0xc09a4ecd,
      0x5a2a7ab9, 0x58b49adf, 0xd1b128d8, 0xd1cd4427, 0x76a936a4, 0x26cc7caa, 0x13505281, 0x1fd0315c,
      0x988fc609, 0xccd5a3a1, 0xd99c3264, 0x6d8a981a, 0xb70491fb, 0x3322c31f, 0x43c110fd, 0x102cb525,
      0x336156ab, 0x2e29ae77, 0xc4dadf1b, 0x2ca1e105, 0x9c92a94b, 0x93cc3679, 0x4502bb92, 0xce0b8b1c,
      0x5a9ff4d1, 0x058c7094, 0xf09c7cf7, 0x4806cbad, 0xd0e49028, 0xf99cb598, 0xa80b2ec5, 0x7093fd4b,
      0xe65a8351, 0xab613222, 0x31cc8cd5, 0xc6573b12, 0x7dd9d283, 0x90a15cc7, 0xdfdc977b, 0x3fa23771,
      0xc050843a, 0xfc8253eb, 0x9f0abe24, 0xf95f6007, 0x6a07b363, 0x54b4060a, 0xbf31efa4, 0x2c3aad79,
      0xda668f25, 0x138e08f2, 0xb71ffacd, 0xfabb4315, 0xd9b09728, 0x518b069e, 0x58ef4db9, 0x25e5befd,
      0xee556e36, 0x4dac0e7c, 0x1da563aa, 0x371e3ff1, 0xa66fa7c0, 0x42cf6640, 0xab5ed351, 0x6e775cbc,
      0x3884e384, 0xbeb449dd, 0x89e83ebc, 0x5fa85af8, 0x2b82bb1d, 0xadc84e52, 0x40412b32, 0xc1efda9b,
      0x4a1498dc, 0xf7f9802b, 0xc79d614e, 0x2fd1d562, 0x2c937e6b, 0x2cc67267, 0xe4269551, 0x0d64550f,
      0xb484068c, 0xcf97aba4, 0x4f89c39b, 0x264ca7fd, 0xfb90a8bd, 0xe4a3f3e4, 0xd6193d63, 0x45241ebc,
      0xb69758d7, 0x6f226586, 0x5e165f36, 0xbd3036a2, 0xef8b1076, 0xe9973a44, 0x6f1e8d4c, 0x63938221,
      0x64e32c50, 0x2274c827, 0xb2a852d2, 0xade0cf8e, 0xdc754ec7, 0x4e0ee5b0, 0x3da5a33a, 0x3fbbe698,
      0x4fdc13c9, 0xdafe50fc, 0x7eaee084, 0x2b4a4db6, 0x70ecc71f, 0x2d6466bf, 0x887238aa, 0xe352b233,
      0xa51111df, 0x3ff037d7, 0x1e97bea0, 0x28d4a977, 0xa8f6d229, 0x2c7e028b, 0xc57a4ed8, 0xc1e3cebb,
      0xe37b50e2, 0xc60bfd20, 0xb41c338f, 0x562630be, 0x733dae05, 0xec91d1c6, 0xefb8356d, 0xda119307,
      0x089d15d3, 0xb162bc0c, 0xdb0f744e, 0xc4010858, 0xc609a665, 0xb843aa52, 0x6f404d13, 0xb50df2f2,
      0x675f5afc, 0xba01e8ec, 0xaadf8be9, 0xe0f62804, 0x3e425609, 0x8528d4f9, 0x1447c4c2, 0x79fc1099,
      0xef9ea8bc, 0x0b2fe3fc, 0xf751a4d0, 0xe344b5b5, 0xd5309cc8, 0x56d9941d, 0xdc49cafd, 0x5e853c0d,
      0x506fac61, 0xf3544583, 0xfbee461b, 0x35f6d16c, 0x17609d3c, 0x47b1b4f8, 0x3cec48cb, 0x86a3dc26,
      0x546198cf, 0xf92ec3eb, 0xb643204d, 0xc16022e3, 0x0fc65eb5, 0xccfdf0fe, 0xd373ff09, 0xaaecb85d,
      0x09d646d2, 0xe493555b, 0x0e025f0f, 0x8c0f1589, 0xace87d02, 0x1b317914, 0x30572122, 0x89c2afb1,
      0x739b8637, 0x515d809b, 0x7d8f0532, 0x278a4b0a, 0xe0cf650e, 0x7dc97523, 0x46412b87, 0x87a8ca0b,
      0x6d38b509, 0x53f43053, 0xf518b807, 0x51fd2f74, 0x169a3162, 0xb41e3f3f, 0xfd1709ce, 0xd5b6842c,
      0x08edc02e, 0x97ab605e, 0x376fd8b4, 0xd9f15175, 0x5b5c7895, 0xedfe87fa, 0x921fb79c, 0x1ef903b1,
      0xb7d6306d, 0x9ad5651f, 0x1bfa727f, 0x0af45c03, 0x08fcbb0d, 0x75faa27a, 0x634667bb, 0x73a24f4b,
      0x275ac6ab, 0x65b40924, 0x1823ed26, 0xf54b58ed, 0xe11783b7, 0x46e586ca, 0x68b2b761, 0x8eae9158,
      0x98e4b860, 0x3cdfb24a, 0x233c5c46, 0xf3d88ed5, 0xce9a2f02, 0x1190e2ad, 0xa13dabc9, 0x324aaa43,
      0x8432ffff, 0xe8f7e68f, 0x5735991e, 0x6c96148d, 0xd3b86a68, 0x443d6b96, 0x8c3cdcec, 0x3e2d193b,
      0xd30fe0e8, 0x25644d66, 0xa5f431ba, 0xd6f4a5a4, 0xea31551f, 0x582090d7, 0x1a531766, 0xf059ae9d,

      0xdb3ebcc4, 0x2bda4aaf, 0x20bac271, 0xb90d38df, 0x4b568da3, 0x4bcc6c15, 0xe80b5af3, 0x796ec8cf,
      0xf155e70a, 0x9fd45cfb, 0xae4dd746, 0x453fc337, 0xf07f9efb, 0x62b57626, 0xdd5b92b8, 0x5688b82d,
      0xbe6ff963, 0xd0c61163, 0x331ccd8a, 0x678c4445, 0x15dea0bb, 0x00d81b06, 0xfb08f804, 0xbca3d291,
      0x4efb666a, 0x06b8f52d, 0xde7d0dd5, 0xcf2cb546, 0xeb721cc0, 0xd08cb6d3, 0x9de906fe, 0x1fef872a,
      0x5a65715c, 0xcb5190f2, 0xef563029, 0xd8b66943, 0x61125692, 0x7db602b9, 0x0242a7d8, 0xfc3d05c1,
      0x2b0b8d82, 0x1fe6c072, 0x54580d2a, 0xbffa360f, 0x1651ae85, 0xed9cfe06, 0x1ab2cfe1, 0x173cedfb,
      0x507ae2b3, 0x5bd83711, 0xdf0269b4, 0x4b2c1cb5, 0xd8263e8e, 0x485c119b, 0x20aa9eed, 0xeed41013,
      0x5d2e8181, 0xad33aff1, 0x86558428, 0x19b0c2d1, 0x56d19f32, 0x4b5074a7, 0xd9450d0d, 0xc2b75b04,
      0x7303ebe4, 0xf635bf11, 0x208cbfee, 0x0fabca2f, 0xe5c30a06, 0x1b286f5a, 0x7a93211c, 0x7afdb3c3,
      0x5e3f4d68, 0x2fb67e54, 0x8598008a, 0xbe1b93d3, 0x0f4ff9dd, 0x91579384, 0x053097b0, 0x3f459325,
      0x75d649e1, 0xa0f4bd59, 0x80bf2d0f, 0x8bc32665, 0xf7ba8068, 0x6c8c0e11, 0xd2ebf7a5, 0x77a1f920,
      0xa9550e7d, 0xf6671ce7, 0x012db171, 0x0a8b92af, 0x4f7551ab, 0xb0932b22, 0xf847f81e, 0x6113c942,
      0x21a2961a, 0x247914b0, 0x2adb9fe0, 0x669264fa, 0xa134f6b2, 0x32d1e836, 0x1dfdb910, 0x21733f4e,
      0x90bb64d8, 0xc0aaa01e, 0xc86d0355, 0x8741e77e, 0xf289393d, 0x105748d1, 0xc46c932e, 0x86a5f854,
      0x7c8500b6, 0x93f37af0, 0x40d836fc, 0xf400590e, 0xbaf3a50e, 0xab2ce175, 0xbeb15ee5, 0x0f38b905,
      0x49a088bc, 0x87279c86, 0xabdb5a50, 0x89f2feb5, 0x7947ba13, 0xdf7febd5, 0xce0bfde9, 0x9a813691,
      0x37c636a8, 0x3acc1cb4, 0x23398068, 0x878f6c1f, 0x83326270, 0x8d83a4ec, 0x4e244c45, 0xb872dc11,
      0x6b6c164c, 0x638766d7, 0x1d6f4194, 0x2091d85d, 0xe3024c88, 0x3f17a427, 0x4a01362b, 0xa835635a,
      0x415347c1, 0x8ab934d7, 0xc1ea2c25, 0xcd5c9f2a, 0x5fe676f0, 0x4d6d433b, 0x67064cc3, 0x829392b8,
      0xfe5028fc, 0xf828f95a, 0x62842ba3, 0xc8937a61, 0x9721369b, 0x50b4ee24, 0x26715742, 0xf1d63969,
      0xd08d5060, 0xadc20379, 0xcc363a2e, 0xdec22480, 0x3617cce8, 0x212f6a17, 0x2a41052c, 0xdb26e527,
      0x99798738, 0xc0812f39, 0xe7f4bdd2, 0x1c7c6c4e, 0x7b5021e1, 0xb4ca630d, 0x50493ff8, 0x9a6e1561,
      0xd51539c8, 0x6692a2ea, 0x0c6c8ad8, 0xfbf8262c, 0x15a544ee, 0x7e9907fc, 0x1f69e99d, 0xdc89af7c,
      0x4461d1d5, 0x7c8f2a65, 0xfe7eb38f, 0x5e1d2677, 0xaba4f1f2, 0x39240176, 0x7dc3701f, 0x315c2223,
      0x20f8b1be, 0x589e1a02, 0xadfcdf3e, 0x530a6730, 0x5e5b1312, 0x29bfefe2, 0xc98d5f75, 0xf08fd234,
      0xb032a4c7, 0x21d11bfa, 0x17fbb322, 0x518364ae, 0xfee830b6, 0x6768f078, 0xdc5fd237, 0x093d7780,
      0x06a3bd70, 0x624d272d, 0x0888ad27, 0xe468defb, 0x536b554b, 0x0f42dba6, 0x6a82db06, 0xf936be6a,
      0x49e0ba24, 0x989688e6, 0x8db88ed1, 0x007cb46f, 0x33322e88, 0x7755778e, 0x42591a84, 0xd25b0004,
      0x41a82b9d, 0x54e17097, 0x3fdc168e, 0x42709cb2, 0xf1094441, 0x4c9405e5, 0x29c94482, 0x94268ccb,
      0x94a73c65, 0x585d3ac3, 0x43b8ae00, 0x10ddbbf9, 0x0f00eff5, 0xd0d656ac, 0xac63368c, 0x9c9f7e8f,
      0x07f892b5, 0xc481e22c, 0x6a2391d9, 0x2b4c127d, 0x5dcd9a72, 0x5f30d21f, 0xaaf0c397, 0xee7b6a83,
      0x222a119c, 0xf3c42075, 0x533fb9ae, 0xaca74163, 0x0cba7998, 0x58e60778, 0x142e3a09, 0x8a685b95,
    ]
    seed = [
      1936287828, 544434464, 1849583932,
      792491119, 1948270185, 1914725736,
      1952999273, 1954114848, 779384933,
    ]

    m = Random::ISAAC.new seed
    numbers.each do |n|
      m.next_u.should eq(n)
    end
  end

  it "can be initialized without explicit seed" do
    Random::ISAAC.new.should be_a Random::ISAAC
  end

  it "different instances generate different numbers (#7976)" do
    isaacs = Array.new(1000) { Random::ISAAC.new }
    values = isaacs.map(&.rand(10_000_000))
    values.uniq.size.should be > 2
  end
end
