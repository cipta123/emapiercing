# EMA Piercing Breakout EA (MetaTrader 5)

Expert Advisor (EA) kuantitatif untuk MetaTrader 5 (MT5) berbasis strategi penembusan (*piercing breakout*) dua garis Exponential Moving Average (EMA Fast 9 & Slow 17) dengan pelindung tren EMA 125, manajemen risiko dinamis, validasi profit searah, dan basket profit otomatis.

Dikembangkan dan dioptimalkan khusus untuk instrumen **Gold (XAUUSD)** pada timeframe **H1** (atau timeframe pilihan).

---

## 📁 Daftar File & Versi

| File | Versi | Fitur Utama |
| :--- | :---: | :--- |
| **`EMA_CrossBreak_EA.mq5`** | v1.00 | Versi dasar: Piercing 1-Bar, Stacking, Filter Validasi Profit Searah, Basket TP Reguler, Martingale opsional, Tombol Close All di Chart. |
| **`EMA_CrossBreak_EA_v1.20.mq5`** | v1.20 | Tambahan **Filter ATR / Ukuran Body**: Hanya mengeksekusi jika ukuran body candle penembus $\ge X \times \text{ATR}$ (menghindari candle kecil/doji). |
| **`EMA_CrossBreak_EA_v1.30.mq5`** | v1.30 | Tambahan **Filter Tren / Reversal EMA 125**: Pilihan mode tren (hanya Buy di atas EMA 125) atau reversal (hanya Sell di atas EMA 125). |
| **`EMA_CrossBreak_EA_v1.40.mq5`** | v1.40 | Tambahan **Mode Breakout Fleksibel (2-Bar Step)** + Kustomisasi Warna/Ketebalan 3 Garis EMA langsung dari input properties. |
| **`EMA_CrossBreak_EA_v1.50.mq5`** | v1.50 | Tambahan **Mode Alur Selang-Seling (Strict Alternating BUY <-> SELL)**: Setelah membuka BUY tidak boleh membuka BUY lagi, wajib menunggu sinyal SELL, begitu pula sebaliknya. |
| **`EMA_CrossBreak_EA_v1.60.mq5`** | v1.60 | Inovasi **Pending Stop Trap (Zero-Lag)**: Berbasis kode dasar v1.00, memasang **SELL STOP** di garis terluar bawah saat harga di atas, dan **BUY STOP** di garis terluar atas saat harga di bawah, tereksekusi instan saat tertembus tanpa tunggu close candle. |
| **`EMA_Visual_Line.mq5`** | Custom Indicator | Indikator pembantu untuk menggambar garis visual EMA warna kustom secara otomatis di chart. |

---

## 🚀 Fitur Unggulan

1. **Logika Trigger Breakout**:
   - **Strict 1-Bar Piercing**: Candle Open di luar kedua EMA dan Close menembus kedua EMA dalam 1 candle.
   - **Flexible 2-Bar Step (v1.40)**: Mendeteksi penembusan bertahap 2 candle saat reli kencang.
2. **Filter Validasi Profit Searah**:
   - Mencegah penambahan posisi baru saat $\ge N$ order terbuka jika posisi sebelumnya masih merugi.
   - Pilihan: Akumulasi Total Basket Searah vs Order Terakhir Searah.
3. **Manajemen Basket Profit**:
   - Basket TP Reguler (menutup seluruh order saat akumulasi profit tercapai, tanpa menunggu batas martingale).
   - Basket TP saat Max Step Martingale tercapai.
4. **Proteksi & Exit Otomatis**:
   - Close posisi berlawanan saat muncul sinyal valid baru (`InpCloseOnOpposite`).
   - Stop Loss (Points atau Candle Buffer) & Take Profit.
   - Trailing Stop & Break-Even otomatis.
5. **Chart GUI Interaktif**:
   - Dashboard informasi live pada chart (status sinyal, total floating, level martingale, status filter profit).
   - Tombol on-chart *"CLOSE ALL ORDERS"* untuk intervensi manual darurat dengan satu klik.

---

## ⚙️ Rekomendasi Parameter Optimal (Hasil Riset Kuantitatif)

Berdasarkan pengujian grid search pada 56.765 candle H1 XAUUSD (12 tahun data: 2014–2026):

- **Timeframe**: H1 (Rekomendasi Utama)
- **Fast EMA / Slow EMA**: 9 / 17
- **Stop Loss**: 300 Points ($3.0 pada Gold)
- **Take Profit**: 0 (Biarkan keuntungan berjalan sampai ada sinyal lawan / basket TP)
- **Max Positions**: 3 Posisi
- **Close on Opposite**: `true`
- **Basket Profit Reguler**: $50.0 USD
- **Filter Validasi Profit**: Aktif (Trigger $\ge$ 3 posisi)

---

## 💻 Cara Pemasangan di MetaTrader 5

1. Buka MT5, klik menu **File -> Open Data Folder**.
2. Masuk ke folder **`MQL5/Experts`**, lalu salin file `.mq5` EA ke folder tersebut.
3. Masuk ke folder **`MQL5/Indicators`**, lalu salin file `EMA_Visual_Line.mq5`.
4. Buka **MetaEditor** (tekan F4), buka file-file tersebut, lalu tekan tombol **Compile (F7)** hingga muncul pesan `0 errors, 0 warnings`.
5. Kembali ke MT5, refresh panel Navigator, pasang EA pada chart XAUUSD, dan aktifkan tombol **Algo Trading**.
