# Kepemilikan `en0` dan urutan interface jaringan

> ★ **Dokumen ini adalah aturan umum**, dirujuk oleh `broadcom-wifi.md` / `intel-wifi.md` / `mediatek-wifi.md` /
> `os-upgrade-15-to-26.md` / `smbios-and-serials.md`.
> **Baca ini dulu sebelum mengubah driver kartu jaringan / memasang patch Wi-Fi / mengganti kartu jaringan.**

## 0. Satu kalimat

**`en0` adalah "kartu jaringan utama" yang dikenali oleh layanan Apple.**
Kernel memberi nomor `en` berdasarkan **urutan pemuatan driver** — **tidak terkait urutan alamat PCI**.
Jadi setelah **memasang / menghapus driver kartu jaringan, memasang patch Wi-Fi, mengganti kartu jaringan**, `en0` bisa **berpindah pemilik**, dan semua yang bergantung padanya ikut terpengaruh.

## 1. Siapa yang bergantung pada `en0`

| yang bergantung | Penjelasan |
|---|---|
| **`PlatformInfo > Generic > ROM`** | Dortania meminta diisi dengan **MAC asli `en0`** ⇒ setelah `en0` berpindah, ROM jadi tidak konsisten (lihat `smbios-and-serials.md` §5.3 / §6.1) |
| **iMessage / FaceTime / App Store** | Identitas mesin ditentukan berdasarkan `en0`; `en0` yang salah menyebabkan "tidak bisa login / sering putus" |
| **Wi-Fi itu sendiri** | Lihat §2 — setelah patch / ganti kartu, pastikan nirkabel memang `en0` |

> ★★ **Yang TIDAK bergantung pada `en0`: AirDrop / Handoff / Continuity.**
> Semuanya hanya bergantung pada "adanya `awdl0`" (= apakah nirkabel memakai stack `IO80211Family` asli Broadcom) + layanan Bluetooth BLE,
> dan **tidak ada hubungannya** dengan `en0` / `ROM` / nomor seri / UUID.
> Sebelumnya dokumen ini mencantumkan `Continuity / AirDrop` di dalam "bergantung pada `en0`" itu **salah** — itu adalah kekeliruan
> karena memperluas kebutuhan **iServices** (iMessage) dari Dortania ke AirDrop (asli Dortania: *"The type doesn't matter"*,
> dan sama sekali tidak menyebut AirDrop; Apple resmi untuk Continuity hanya mensyaratkan "Apple ID yang sama + Wi-Fi + Bluetooth").
> ⇒ **Untuk troubleshooting AirDrop, gunakan `airdrop-handoff.md`, jangan mencari di sini.**

## 2. ★★ Mengapa setelah "patch Wi-Fi" wajib memastikan `en0`

Menerapkan **OCLP root patch**, **mengganti kartu jaringan**, **menambah/menghapus kext kartu jaringan** semuanya mengubah **urutan pemuatan driver** ⇒
**nirkabel bisa turun dari `en0` ke `en1` (atau kabel mengambil `en0`)**. Akibatnya:

- `ROM` dan `en0` tidak konsisten ⇒ **iMessage / FaceTime / App Store bisa bermasalah**
- Layanan yang bergantung pada "kartu jaringan utama" berperilaku aneh

> ★ **AirDrop / Handoff tidak akan gagal karena itu** — itu urusan `awdl0` (lihat `airdrop-handoff.md`).
> Jangan mengaitkan "setelah ganti kartu AirDrop rusak" dengan `en0` yang berpindah.

⇒ **Karena itu alur patch Wi-Fi (`broadcom-wifi.md` §3 / `os-upgrade-15-to-26.md` setelah upgrade) wajib ditambah satu langkah:
pastikan `en0` itu nirkabel atau bukan.**

## 3. Cara memeriksanya

```bash
networksetup -listallhardwareports      # lihat en mana yang untuk Wi-Fi
ifconfig en0 | head -3                  # MAC dan status en0
ioreg -l -w0 | grep -i "IOBuiltin"      # tanda built-in
scutil --nwi                            # interface jaringan utama saat ini
```

**Kriteria**: pada `networksetup -listallhardwareports`, **Device yang ditampilkan di bagian Wi-Fi adalah `en0`** (bukan `en1`).

## 4. Cara "memaku" nirkabel ke `en0`

```bash
# ① Nonaktifkan sementara driver kabel (pada mesin ini = AppleIGC.kext)
#    OpenCore: Kernel > Add > AppleIGC.kext dengan Enabled = false
# ② Hapus cache urutan interface
sudo rm /Library/Preferences/SystemConfiguration/NetworkInterfaces.plist
# ③ Restart
# ④ Setelah aktif, pastikan Wi-Fi = en0
networksetup -listallhardwareports
# ⑤ Bila perlu, kembalikan driver kabel (nomor sudah terkunci, tidak akan merebut lagi)
```

★ **Setelah restart, nirkabel bisa terkunci dulu di 2.4 GHz** ⇒ reset sekali:

```bash
networksetup -setairportpower en0 off
networksetup -setairportpower en0 on
```

## 5. Dampak lanjutan: apakah `ROM` perlu ikut diubah

Setelah `en0` berpindah pemilik, `ROM` (= MAC dari `en0` lama) tidak lagi konsisten dengan `en0` saat ini.

- **Ubah** ⇒ harus membayar lagi biaya "membangun ulang `ByHost` + autentikasi ulang"
- **Tidak diubah** ⇒ dalam kebanyakan kasus tetap bisa dipakai, tapi tidak sesuai aturan Dortania

⇒ Ini adalah **kompromi yang harus Anda putuskan sendiri** (lihat `smbios-and-serials.md` §6.1).
**Catat MAC kedua sisi sebelum mengganti** (secara lokal, jangan dimasukkan ke repositori).

## 6. Disiplin kriteria

- ★ **Lihat `ifconfig`, jangan hanya `system_profiler`** — setelah restart driver harus membaca kartu, mengaitkan, dan DHCP, **butuh belasan detik**,
  selama itu `system_profiler` mengembalikan kosong ⇒ mudah salah menilai sebagai "gagal" (lihat `broadcom-wifi.md` §4)
- Apakah nirkabel benar-benar hidup: `ifconfig en0` (atau `en1`) harus punya **`inet` + `status: active`**
- **`awdl0` ada** ⇒ AirDrop / Handoff **berpeluang** (kriteria lengkapnya ada di `airdrop-handoff.md`:
  juga butuh `llw0` + Bluetooth `LEA`/`AACP`/`GATT`)
- Setelah mengganti kartu jaringan, **jangan menyuntikkan beberapa set driver kartu jaringan sekaligus pada mesin yang sama** (`intel-wifi.md` §5)
