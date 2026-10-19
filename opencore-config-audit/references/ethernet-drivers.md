# Driver pihak ketiga untuk kartu jaringan kabel (Intel / Realtek)

> Berdasarkan: README resmi **`SimpleVGBE`** / **`SimpleGBE`** / **`SimpleHacPlugins`** / **`SimpleRTK5`** dari `laobamac`.
> **Terkait**: `network-en0-order.md` (★ mengganti driver mengubah kepemilikan `en0`), `intel-wifi.md` §5 (setelah mengganti kartu jaringan, driver lama harus dibersihkan),
> `laobamac-toolkit.md` (indeks alat).

## 0. Kapan dibutuhkan

Kartu jaringan kabel onboard / tambahan yang **tidak dikenali secara native** oleh macOS.

> ★★ **Kartu onboard mesin ini (ASUS Z690) adalah Intel `I225-V`** —— tidak dikenali secara native, wajib memakai driver pihak ketiga.
> ★ **Ada juga jalur ACPI**: **`Intel_I225-V_Fix_(SSDT-I225V)`** dari `5T33Z0/OC-Little-Translated`
> (memperbaiki dengan SSDT, bukan memasang kext) —— layak dibandingkan, lihat `acpi-ssdt.md` §0.1.
> Mesin ini saat ini memakai **`AppleIGC.kext`**, solusi dalam dokumen ini adalah **alternatif**-nya.

## 1. Intel 2.5G —— **I225 / I226**

| Solusi | Keterangan |
|---|---|
| **`laobamac/SimpleVGBE`** | *"Intel **2.5G** Ethernet driver for macOS. Based on **I225** firmware in LinuxKernel V6.5"* —— mendukung **I225 / I226** (ID hardware spesifik lihat repositori `igc_hw.h`); diports dari driver IGC Linux |
| **`laobamac/SimpleHacPlugins` → `SimpleEthernet`** | **Plugin Lilu**, menyuntik driver i225/226/210/211. Kutipan asli: *"Put it into `EFI/OC/Kexts` and enable it, then reboot. **Only Ventura and newer system need it!**"*; hasil uji Sonoma 14.5 **laju 2.5G dan jaringan mesin virtual normal** |

**Dukungan (`SimpleVGBE`)**: IPv4/IPv6 DHCP · TCP checksum · **TSO / TSO6** · hot-plug kabel jaringan dan penetapan ulang · mendukung Sequoia
**Batasan yang diketahui**: laju paksa **tidak berlaku** karena dipengaruhi `igc_ethtool_set_link_ksettings()`

> ★ **Perhatikan pada mesin ini**: mengganti driver mengubah **urutan pemasangan driver** ⇒ **berpotensi membuat `en0` berpindah** (lihat `network-en0-order.md`).
> **Sebelum mengganti, catat dulu siapa `en0` saat ini** (`networksetup -listallhardwareports`).

## 2. Intel Gigabit —— I210 / I211 / 82575·76·80 / I350

| Solusi | Keterangan |
|---|---|
| `laobamac/SimpleGBE` | Diports dari `EthernetIgb-5.17.4` Ubuntu; mendukung **I210 · I211 · 82575/82576/82580 · I350/I350T4**; **mendukung Sequoia**; sejak v1.0.1 mendukung **laju kustom dan MTU 9000** |
| `SimpleHacPlugins → SakuraLegacyFix` | Intel **I350 / X540** —— **dalam pengujian, belum ada unduhan** (penulisnya berniat menggabungkannya ke `SakuraEthernet`) |

> ⚠️ **`SimpleGBE` berstatus arsip sejak 2026-06-18**, tidak lagi diperbarui (kutipan penulis).

## 3. Realtek —— RTL8125 / RTL8126

| Solusi | Keterangan |
|---|---|
| **`laobamac/SimpleRTK5`** | **Driver 2.5 / 5GbE untuk RTL8125 / 8126**; kompatibel secara native dengan network stack macOS (**mendukung AppleVTD**); mendukung **ASPM** dan **TSO**; **interval polling** dapat diatur lewat boot-arg / device property |
| ~~`laobamac/SimpleRTLHV`~~ | ★ **sudah digabungkan ke `SimpleRTK5`, jangan digunakan sendiri lagi** (posisi awal: plugin Lilu untuk RTL8125 2.5G) |

## 4. Cara memasang dan kriteria

**Memasang**:

1. Letakkan `.kext` ke dalam `EFI/OC/Kexts/`, tambahkan entri di `Kernel → Add`
   ★ **`SimpleEthernet` adalah plugin Lilu** ⇒ harus berada **setelah `Lilu`**
2. Modifikasi ESP dengan **prosedur aman**: cadangan → ubah → `plutil -lint` → `ocvalidate` → `sync` → lepas-pasang ulang → verifikasi ulang sha

**★ Disiplin: hanya ganti satu set dalam satu waktu** ——
**Jangan menyuntik beberapa set driver jaringan kabel sekaligus pada mesin yang sama** (`AppleIGC` + `SimpleVGBE` akan **saling merebut perangkat**).
Saat mengganti driver, setel dulu set lama ke `Enabled=false` atau hapus (kriteria lihat `disks-and-kexts.md`).

**Validasi**:

```bash
ifconfig en0 | head -3                  # apakah ada inet + status: active
networksetup -listallhardwareports      # ★ konfirmasi kepemilikan en0 (lihat network-en0-order.md)
system_profiler SPEthernetDataType | head -30
```

> ★★ **Setelah mengganti, wajib memeriksa ulang `en0`** —— mengganti driver mengubah urutan pemasangan, `en0` bisa berpindah ⇒
> `ROM` / iMessage / FaceTime / App Store akan **gagal diam-diam** (lihat detail di `network-en0-order.md`).
> ★ **AirDrop / Serah Terima tidak terpengaruh** (hanya melihat `awdl0`, lihat `airdrop-handoff.md`).

## 5. Catatan keamanan

- Semua kext ini **bukan bertanda tangan Apple** ⇒ memerlukan `SecureBootModel=Disabled`, SIP dilonggarkan sesuai kebutuhan
- Saat mengambil paket dari Releases, **verifikasi repositori sumber dan hash file**; proyek **yang sudah diarsipkan** seperti `SimpleGBE` tidak akan memperbaiki bug lagi
- Kartu jaringan kabel **tidak memengaruhi Wi-Fi**, tetapi memengaruhi kepemilikan `en0` dan urutan layanan jaringan ⇒ setelah mengubah, sekilas lihat urutan layanan di "Pengaturan Sistem → Jaringan"
