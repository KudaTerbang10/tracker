require('dotenv').config();
const dns = require('dns');
const mongoose = require('mongoose');

dns.setServers(['8.8.8.8', '1.1.1.1']);

const User = require('./models/User');
const Cabang = require('./models/Cabang');

async function seed() {
  try {
    await mongoose.connect(process.env.MONGO_URI, { serverSelectionTimeoutMS: 10000 });
    console.log('Connected to MongoDB');

    await Promise.all([
      User.deleteMany({}),
      Cabang.deleteMany({}),
    ]);
    console.log('Cleared existing data');

    const cabangs = await Cabang.insertMany([
      { kode: "TNG", name: "Tangerang Selatan", address: "Jl. Serpong km. 8, Pakulonan, Tangerang Selatan 15325", phone: "(021)-5396529", kota: "Tangerang Selatan", lokasi: { type: 'Point', coordinates: [106.64749884908083, -6.241551497744919] } },
      { kode: "BGO", name: "Bogor Pasar Anyar", address: "Pasar Anyar, Bogor", phone: "0811-2696-691", kota: "Bogor", lokasi: { type: 'Point', coordinates: [106.79189378252582, -6.5923233303975435] } },
      { kode: "BDD", name: "Bandung Buah Batu", address: "Jl. Terusan Buah Batu No. 100, Bandung", phone: "0811-2696-484 / 0811-2696-464", kota: "Bandung", lokasi: { type: 'Point', coordinates: [107.63896352653553, -6.954608126442076] } },
      { kode: "TSK", name: "Tasikmalaya", address: "Jl. Moh Hatta No. 121, Kec. Cipedes, Tasikmalaya 46131", phone: "081646993590", kota: "Tasikmalaya", lokasi: { type: 'Point', coordinates: [108.24373003988127, -7.30411265896764] } },
      { kode: "TGL", name: "Tegal", address: "Jl. Kapten Sudibyo No. 86, Pekauman, Tegal 52125", phone: "(0283)-356201", kota: "Tegal", lokasi: { type: 'Point', coordinates: [109.127675081024, -6.872867010102326] } },
      { kode: "SMA", name: "Semarang Anjasmoro", address: "Jl. Puri Anjasmoro Blok DD 1 No. 16, Tawangsari, Semarang 50144", phone: "(024)-7607356", kota: "Semarang", lokasi: { type: 'Point', coordinates: [110.39088676753146, -6.963870846481917] } },
      { kode: "UGN", name: "Ungaran", address: "Jl. Diponegoro No. 240, Mijen, Ungaran 50511", phone: "(024)-6922320", kota: "Ungaran", lokasi: { type: 'Point', coordinates: [110.40939565219313, -7.15219534046155] } },
      { kode: "SUB", name: "Surabaya Tambak Mayor", address: "Jl. Tambak Mayor No. 20, Kec. Asemrowo, Surabaya 60182", phone: "(031)-7496442 / 0811-2696-524", kota: "Surabaya", lokasi: { type: 'Point', coordinates: [112.70819299452393, -7.2533384208266956] } },
      { kode: "SBB", name: "Surabaya Sidotopo", address: "Jl. Sidotopo Lor No. 10I, Sidotopo, Kec. Semampir, Surabaya 60152", phone: "0811-2696-430", kota: "Surabaya", lokasi: { type: 'Point', coordinates: [112.75429579452363, -7.233419232068209] } },
      { kode: "JLM", name: "Jakarta Jelambar", address: "Jl. Penerangan No. 51, Jelambar Kec. Grogol, Jakarta Barat 11460", phone: "(021)-6570758", kota: "Jakarta Barat", lokasi: { type: 'Point', coordinates: [106.78148650398197, -6.163837918354764] } },
      { kode: "BDC", name: "Bandung Pungkur", address: "Jl. Pungkur No. 127 B, Bandung", phone: "0811-2696-463", kota: "Bandung", lokasi: { type: 'Point', coordinates: [107.60963180564696, -6.928318281457911] } },
      { kode: "CBN", name: "Cirebon", address: "Jl. Ahmad Yani No. 34, Pegambiran, Kec. Lemahwungkuk, Cirebon 45113", phone: "(0231)-206424", kota: "Cirebon", lokasi: { type: 'Point', coordinates: [108.58051556752801, -6.7394017539584885] } },
      { kode: "SMB", name: "Semarang Semeru", address: "Jl. Semeru Raya No. 41, Gajahmungkur, Semarang 50231", phone: "0811-2696-514", kota: "Semarang", lokasi: { type: 'Point', coordinates: [110.4135707945203, -7.019869396149802] } },
      { kode: "KDS", name: "Kudus", address: "Jl. AKBP Agil Kusumadya No. 123, Jatimulyo, Kec. Jati, Kudus 59346", phone: "(0291)-431728 / 0811-2696-512", kota: "Kudus", lokasi: { type: 'Point', coordinates: [110.8255419368467, -6.833865535531045] } },
      { kode: "MGL", name: "Magelang", address: "Jl. Urip Sumoharjo No. 51, Cacaban, Magelang 56121", phone: "(0293)-362286 / 0811-2696-510", kota: "Magelang", lokasi: { type: 'Point', coordinates: [110.22202661107355, -7.465361871466776] } },
      { kode: "SKH", name: "Sukoharjo", address: "Jl. Raya Grogol No. 23, Dusun II, Madegondo, Kec. Grogol, Kab. Sukoharjo 57157", phone: "0811-2696-516", kota: "Solo", lokasi: { type: 'Point', coordinates: [110.82061332336494, -7.596816149739666] } },
      { kode: "YOG", name: "Yogyakarta Jetis", address: "Jl. Tentara Zeni Pelajar No.27, Bumijo, Kec. Jetis, Kota Yogyakarta, Daerah Istimewa Yogyakarta 55231", phone: "(0274)-553012 / 0811-2696-516", kota: "Yogyakarta", lokasi: { type: 'Point', coordinates: [110.35844610279601, -7.785260128016407] } },
      { kode: "SDB", name: "Sidoarjo Puri", address: "Ruko Puri Indah Blok RK. 05, Perum Puri Indah, Cemengkalang, Sidoarjo 61234", phone: "(031)-99715688", kota: "Sidoarjo", lokasi: { type: 'Point', coordinates: [112.68874750802117, -7.443730354710381] } },
      { kode: "DPS", name: "Denpasar", address: "Jl. Cargo Permai No. 16B, Ubung, Denpasar 80111", phone: "(0361)-411376", kota: "Denpasar", lokasi: { type: 'Point', coordinates: [115.19747728033327, -8.633694960694454] } },
      { kode: "MGB", name: "Jakarta Mangga Besar", address: "Jl. Mangga Besar 4 M No. 50, Kec. Taman Sari, Jakarta Barat 11150", phone: "(021)-6590993", kota: "Jakarta Barat", lokasi: { type: 'Point', coordinates: [106.82294482334265, -6.153090557608883] } },
      { kode: "JTN", name: "Jakarta Jatinegara", address: "Pintu Masuk Gedung Parkir Pasar Jatinegara, Jl. Raya Jatinegara Barat, Jakarta Timur 13320", phone: "(021)-8519589", kota: "Jakarta Timur", lokasi: { type: 'Point', coordinates: [106.8626969554434, -6.215017573487658] } },
      { kode: "KHM", name: "Jakarta Mas Mansyur", address: "Jl. KH. Mas Mansyur No. 15D, Kec. Tanah Abang, Jakarta Pusat 10240", phone: "(021)-1905815", kota: "Jakarta Pusat", lokasi: { type: 'Point', coordinates: [106.81531862766444, -6.190548975646167] } },
      { kode: "BKS", name: "Bekasi", address: "Jl. Ir. H. Juanda No. 39, Margahayu, Bekasi Timur 17111", phone: "0813-1959-8365", kota: "Bekasi", lokasi: { type: 'Point', coordinates: [107.02945902984186, -6.25157891515307] } },
      { kode: "PWK", name: "Purwokerto", address: "Jl. Martadireja 1 No. 975, Purwokerto Wetan, Kab. Banyumas, Purwokerto 53113", phone: "(0281)-6510794", kota: "Purwokerto", lokasi: { type: 'Point', coordinates: [109.25149892336209, -7.423171681245161] } },
      { kode: "JBB", name: "Jakarta Bojong Raya", address: "Jl. Bojong Raya No. 97, Rawa Buaya, Cengkareng, Jakarta Barat 11740", phone: "(021)-5814326", kota: "Jakarta Barat", lokasi: { type: 'Point', coordinates: [106.7333458890681, -6.170877313027029] } },
      { kode: "PGB", name: "Jakarta Pulo Gebang", address: "Jl. Komarudin Lama 107 Pulo Gebang, Cakung, Jakarta Timur 13950", phone: "(021)-86608630 / (021)-8606523", kota: "Jakarta Timur", lokasi: { type: 'Point', coordinates: [106.94312072334316, -6.194103195178223] } },
      { kode: "KKC", name: "Jakarta Kebon Kacang", address: "Jl. Kebon Kacang 1 (Pusat Grosir Metro Tanah Abang, Pintu Keluar Kebon Kacang 1), Jakarta Pusat 10240", phone: "0858-4293-6780 / 0878-9667-5446", kota: "Jakarta Pusat", lokasi: { type: 'Point', coordinates: [106.8161058362081, -6.188017815956004] } },
      { kode: "MGD", name: "Jakarta Mangga Dua", address: "ITC Mangga Dua Raya, Lantai Dasar Blok E1 No. 12, Jl. Mangga Dua Raya, Jakarta Utara 14430", phone: "(021)-62300314", kota: "Jakarta Utara", lokasi: { type: 'Point', coordinates: [106.8249254521777, -6.135866648532799] } },
      { kode: "ALY", name: "Jakarta Alaydrus", address: "Jl. Alaydrus No. 16, Petojo Utara, Kec. Gambir, Jakarta Pusat 10130", phone: "(021)-63868028", kota: "Jakarta Pusat", lokasi: { type: 'Point', coordinates: [106.81394263520701, -6.164560667744887] } },
      { kode: "ASM", name: "Jakarta Asemka", address: "Pusat Grosir Asemka, Pasar Pagi, Parkir Mobil Lantai Dasar, Jakarta Barat 11110", phone: "08112696716", kota: "Jakarta Barat", lokasi: { type: 'Point', coordinates: [106.81200729450707, -6.140202082721924] } },
      { kode: "BGR", name: "Bogor", address: "Jl. Raya Kedung Halang Talang No. 139 B, Cibuluh, Bogor", phone: "0811-2696-706", kota: "Bogor", lokasi: { type: 'Point', coordinates: [106.8135655028376, -6.559590856983367] } },
      { kode: "BDA", name: "Bandung Gede Bage", address: "Jl. Rumah Sakit No. 108 Gedung 23 B, Bandung", phone: "(022)-63756599 / 0811-2696-522", kota: "Bandung", lokasi: { type: 'Point', coordinates: [107.69301572864035, -6.929931257180347] } },
      { kode: "BDB", name: "Bandung Holis", address: "Jl. Taman Holis Indah, Ruko Blok D 18, Cigondewah Kidul, Bandung", phone: "(022)-6024661", kota: "Bandung", lokasi: { type: 'Point', coordinates: [107.564197, -6.940471] } },
      { kode: "CBR", name: "Cirebon Tegal Gubug", address: "Pintu Parkir Barat No 2 Pasar Sandang Tegal Gubug, Cirebon", phone: "08112692508", kota: "Cirebon", lokasi: { type: 'Point', coordinates: [108.3896799929637, -6.635870900801073] } },
      { kode: "PKL", name: "Pekalongan", address: "Jl. Dr Sutomo 37, Kel. Karangmalang, Kec. Pekalongan Timur", phone: "(0285)-434771 / 08112696462", kota: "Pekalongan", lokasi: { type: 'Point', coordinates: [109.67121235218914, -6.899670988538477] } },
      { kode: "SMG", name: "Semarang Genuk", address: "Komplek Pangkalan Truck Genuk Blok AA 57-58, Jl. Kaligawe, Genuksari, Semarang 50117", phone: "(024)-6584125 / 0811-2696-515", kota: "Semarang", lokasi: { type: 'Point', coordinates: [110.47627544907628, -6.960129457478875] } },
      { kode: "YGK", name: "Yogyakarta Mlati Magelang", address: "Jl. Magelang No.B 50, Kutu Asem, Sinduadi, Kec. Mlati, Magelang, Daerah Istimewa Yogyakarta 55242", phone: "(0274)589872", kota: "Yogyakarta", lokasi: { type: 'Point', coordinates: [110.358422, -7.785169] } },
      { kode: "SBA", name: "Surabaya Setail", address: "Jl. Setail No. 7, Darmo, Kec. Wonokromo, Surabaya 60241", phone: "(031)-5671914", kota: "Surabaya", lokasi: { type: 'Point', coordinates: [112.73783255219531, -7.295465398843514] } },
      { kode: "SDA", name: "Sidoarjo Katamso", address: "Jl. Brigjend Katamso No. 85, Janti, Kec. Waru, Sidoarjo 61256", phone: "(031)-8534553", kota: "Sidoarjo", lokasi: { type: 'Point', coordinates: [112.75788019790502, -7.350479391730918] } },
      { kode: "JMB", name: "Jember", address: "Jl. Basuki Rahmat No. 180, Muktisari, Kec. Kaliwates, Jember 68131", phone: "0811-2723-889", kota: "Jember", lokasi: { type: 'Point', coordinates: [113.69828206570466, -8.203108082134312] } },
      { kode: "KDR", name: "Kediri", address: "Jl. Raya Janti, Kec. Papar (Sekitar SMKN 1 Papar / Sebelah RM. Lesehan Mbak Diana), Kediri", phone: "0852-3674-4463", kota: "Kediri", lokasi: { type: 'Point', coordinates: [112.0692524233669, -7.715622465478384] } },
      { kode: "MLG", name: "Malang", address: "Ruko Sulawesi Indah Blok 2A No. 29C, Jl. Yulius Usman, Kec. Klojen, Malang 65117", phone: "(0341)-322575", kota: "Malang", lokasi: { type: 'Point', coordinates: [112.62643702337155, -7.985969368939523] } },
      { kode: "TAB", name: "Tanah Abang", address: "Lobby Barat Blok B Pasar Tanah Abang, Jakarta Pusat", phone: "0858-4293-6780 / 0878-9667-5446", kota: "Jakarta Pusat", lokasi: { type: 'Point', coordinates: [106.81455616664564, -6.1881149778320035] } },
      { kode: "SOL", name: "Solo Banjarsari", address: "Jalan Kaliwingko No.23, Timuran, Kec. Banjarsari, Kota Surakarta, Jawa Tengah 57141", phone: "(0271)-624919", kota: "Solo", lokasi: { type: 'Point', coordinates: [110.816712, -7.56672] } },
    ]);
    console.log(`Created ${cabangs.length} cabangs`);

    const usersData = [
      { name: 'Super Admin', email: 'superadmin@ekspedisi.id', password: 'admin123', phone: '0810000001', role: 'super_admin' },
      { name: 'Hendra Driver', email: 'driver@ekspedisi.id', password: 'driver123', phone: '0810000004', role: 'driver' },
      { name: 'Budi Driver', email: 'driver2@ekspedisi.id', password: 'driver123', phone: '0810000005', role: 'driver' },
    ];

    for (const c of cabangs) {
      usersData.push({
        name: `Admin ${c.name}`,
        email: `${c.kode.toLowerCase()}@ekspedisi.id`,
        password: 'cabang123',
        phone: c.phone,
        role: 'admin_cabang',
        cabang_id: c._id,
      });
    }

    const users = await User.insertMany(usersData);
    console.log(`Created ${users.length} users`);

    console.log('\n=== AKUN LOGIN ===');
    console.log('Super Admin       | superadmin@ekspedisi.id | admin123');
    console.log('Driver 1          | driver@ekspedisi.id     | driver123');
    console.log('Driver 2          | driver2@ekspedisi.id    | driver123');
    console.log(`Admin Cabang      | {kode}@ekspedisi.id     | cabang123 (${cabangs.length} cabang)`);
    console.log('==================\n');

    await mongoose.disconnect();
    console.log('Seed completed!');
    process.exit(0);
  } catch (error) {
    console.error('Seed error:', error.message);
    console.error('Pastikan IP Anda sudah diwhitelist di MongoDB Atlas Network Access');
    process.exit(1);
  }
}

seed();
