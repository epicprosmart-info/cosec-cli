# cosec-cli

[English](README.md) · [Releases](https://github.com/epicprosmart-info/cosec-cli/releases) · [คู่มือ CI](https://cosec-shield.epicprosmart.com/#/help/ci) · [ความปลอดภัย](SECURITY.md) · [สัญญาอนุญาต](LICENSE.md)

เครื่องมือบรรทัดคำสั่งของ [CoSec Shield](https://cosec-shield.epicprosmart.com): อัปโหลด SBOM จาก CI ใดก็ได้แล้วให้ build
fail เมื่อ gate ของ project เป็น `fail`, ดูผลกระทบจาก threat case (`case php2shell`), ตรวจไฟล์ audit ที่เข้ารหัสแบบออฟไลน์
(`audit verify`) และเชื่อม AI agent ผ่าน MCP bridge (`mcp connect`)

binary เดียว static ไม่ต้องมี runtime สำหรับ **Linux, macOS และ Windows** ทั้ง amd64 และ arm64 — release ล่าสุด: **v1.0.0-rc.1**

> repository นี้แจก **binary เท่านั้น** ไม่มี source code; archive "Source code" ที่ GitHub แนบให้ทุก release โดยอัตโนมัติ
> มีแค่ไฟล์ที่เห็นในหน้านี้

## ติดตั้ง

ทุกวิธีด้านล่างดาวน์โหลด archive **และ** `SHA256SUMS` จาก release เดียวกัน แล้วตรวจ sha256 ก่อนแตกไฟล์เสมอ เลือกวิธีใดวิธีหนึ่งต่อ OS

### macOS (12 ขึ้นไป ทั้ง Apple Silicon และ Intel)

**Homebrew**

```sh
brew install epicprosmart-info/tap/cosec-cli      # อัปเกรดภายหลัง: brew upgrade cosec-cli
```

**สคริปต์ติดตั้ง** (ดาวน์โหลด → อ่าน → รัน)

```sh
curl -fsSLO https://github.com/epicprosmart-info/cosec-cli/releases/latest/download/install.sh
sh install.sh                                    # ระบุเวอร์ชัน: COSEC_CLI_VERSION=v1.0.0-rc.1 sh install.sh
```

**ด้วยมือ**

```sh
V=v1.0.0-rc.1; B=https://github.com/epicprosmart-info/cosec-cli/releases/download/$V
curl -fsSLO "$B/cosec-cli_${V}_darwin_arm64.tar.gz" && curl -fsSLO "$B/SHA256SUMS"   # Intel: darwin_amd64
grep "_darwin_arm64.tar.gz$" SHA256SUMS | shasum -a 256 -c -
tar -xzf "cosec-cli_${V}_darwin_arm64.tar.gz" cosec-cli && sudo install -m 0755 cosec-cli /usr/local/bin/
cosec-cli --version
```

เฉพาะไฟล์ที่บันทึกผ่าน **browser** จะติด quarantine ให้ลบด้วย `xattr -d com.apple.quarantine /usr/local/bin/cosec-cli`
ไฟล์จาก `curl`, Homebrew หรือสคริปต์ไม่ต้องทำ

### Windows (10 / Server 2016 ขึ้นไป ไม่ต้องใช้สิทธิ์ Administrator)

**Scoop**

```powershell
scoop bucket add epicprosmart-info https://github.com/epicprosmart-info/scoop-bucket
scoop install cosec-cli                          # อัปเกรดภายหลัง: scoop update cosec-cli
```

**สคริปต์ติดตั้ง** (PowerShell 5.1 หรือ 7; ติดตั้งลง `%LOCALAPPDATA%\Programs\cosec-cli` และเพิ่มลง PATH ของผู้ใช้)

```powershell
Invoke-WebRequest https://github.com/epicprosmart-info/cosec-cli/releases/latest/download/install.ps1 -OutFile install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1          # ระบุเวอร์ชัน: -Version v1.0.0-rc.1
```

**ด้วยมือ**

```powershell
$v = 'v1.0.0-rc.1'; $b = "https://github.com/epicprosmart-info/cosec-cli/releases/download/$v"
Invoke-WebRequest "$b/cosec-cli_${v}_windows_amd64.zip" -OutFile cosec-cli.zip      # ARM: windows_arm64
Invoke-WebRequest "$b/SHA256SUMS" -OutFile SHA256SUMS
$want = (Select-String -Path SHA256SUMS -Pattern '_windows_amd64\.zip$').Line.Split(' ')[0]
if ((Get-FileHash cosec-cli.zip -Algorithm SHA256).Hash.ToLower() -ne $want) { throw 'checksum mismatch' }
Expand-Archive cosec-cli.zip -DestinationPath "$env:LOCALAPPDATA\Programs\cosec-cli" -Force
$env:Path += ";$env:LOCALAPPDATA\Programs\cosec-cli"      # เฉพาะหน้าต่างนี้ — สคริปต์จะตั้งให้ถาวร
cosec-cli --version
```

### Linux (ทุก distribution รวม Alpine)

**สคริปต์ติดตั้ง** (POSIX `sh`; ต้องมี `curl` หรือ `wget` และ `tar`)

```sh
curl -fsSLO https://github.com/epicprosmart-info/cosec-cli/releases/latest/download/install.sh
sh install.sh                                    # ระบุเวอร์ชัน: COSEC_CLI_VERSION=v1.0.0-rc.1 sh install.sh
```

สคริปต์ติดตั้งลง `/usr/local/bin` เมื่อเขียนได้ มิฉะนั้นลง `~/.local/bin` และไม่เรียก `sudo` เอง ตั้ง `COSEC_CLI_INSTALL_DIR`
เพื่อเลือกโฟลเดอร์ และ `COSEC_CLI_BASE_URL` เพื่อใช้ mirror ภายในองค์กร

**แพ็กเกจ** (Debian/Ubuntu หรือ RHEL/Fedora; ติดตั้ง `/usr/bin/cosec-cli` ไม่มี service ไม่มี dependency)

```sh
V=v1.0.0-rc.1; B=https://github.com/epicprosmart-info/cosec-cli/releases/download/$V
curl -fsSLO "$B/cosec-cli_${V#v}_amd64.deb" && curl -fsSLO "$B/SHA256SUMS" && sha256sum -c --ignore-missing SHA256SUMS
sudo dpkg -i "cosec-cli_${V#v}_amd64.deb"       # RHEL / Fedora: sudo rpm -i cosec-cli_${V#v}_amd64.rpm
```

**ด้วยมือ** (ใช้ใน Dockerfile / runner image ด้วย: pin เวอร์ชัน, layer คงที่)

```sh
V=v1.0.0-rc.1; B=https://github.com/epicprosmart-info/cosec-cli/releases/download/$V
curl -fsSLO "$B/cosec-cli_${V}_linux_amd64.tar.gz" && curl -fsSLO "$B/SHA256SUMS"   # ARM: linux_arm64
sha256sum -c --ignore-missing SHA256SUMS
tar -xzf "cosec-cli_${V}_linux_amd64.tar.gz" cosec-cli && sudo install -m 0755 cosec-cli /usr/local/bin/
cosec-cli --version
```

## ตรวจสอบไฟล์ release

| ไฟล์ | คืออะไร |
|---|---|
| `cosec-cli_<tag>_<os>_<arch>.tar.gz` / `.zip` | binary เดียว `cosec-cli` หรือ `cosec-cli.exe` ที่ root ของ archive |
| `cosec-cli_<x.y.z>_<arch>.deb` / `.rpm` | binary Linux ตัวเดียวกันในรูปแพ็กเกจ |
| `*.cdx.json` | SBOM แบบ CycloneDX ของแต่ละ binary |
| `SHA256SUMS` | sha256 ของทุกไฟล์ข้างบนและสคริปต์ติดตั้ง |
| `SHA256SUMS.sig` | ลายเซ็น cosign ของ `SHA256SUMS` (แนบเมื่อ release ลงชื่อแล้ว; key: [`cosign.pub`](cosign.pub)) |
| `install.sh`, `install.ps1` | สคริปต์ข้างบน ชุดเดียวกับบน `main` ณ tag นี้ |
| `release.json` | รายการไฟล์พร้อม sha256 และ URL สำหรับเครื่องอ่าน |

```sh
sha256sum -c --ignore-missing SHA256SUMS                                   # macOS: shasum -a 256 -c
cosign verify-blob --key cosign.pub --signature SHA256SUMS.sig SHA256SUMS  # เมื่อมี SHA256SUMS.sig
```

ถ้าไม่ตรงแปลว่าไฟล์เสียหรือถูกแก้ ให้ลบแล้วดาวน์โหลดใหม่ ถ้าเกิดซ้ำให้รายงานตาม [SECURITY.md](SECURITY.md)

## ใช้ใน CI

```sh
export COSEC_URL=https://cosec.example.com COSEC_PROJECT=01H…    # COSEC_TOKEN มาจาก secret store ของ CI
syft . -o cyclonedx-json > project_sbom.json
cosec-cli --file project_sbom.json --commit "$(git rev-parse HEAD)" --timeout 5m
```

| Exit code | ความหมาย |
|:---:|---|
| 0 | gate `pass` (หรือ `warn` เมื่อไม่ได้ใส่ `--fail-on warn`) |
| 1 | gate `fail` |
| 2 | ใช้งานผิด / อัปโหลดไม่สำเร็จ (แสดงเหตุผล) |
| 3 | รอผลสแกนเกินเวลา |

token อ่านจากตัวแปร `COSEC_TOKEN` เท่านั้น (ไม่มี flag) และปฏิเสธ `http://` ยกเว้น localhost

- **GitHub Actions**: ใช้ action แทน ไม่ต้องมี binary: `epicprosmart-info/cosec-shield/.github/actions/cosec-gate@v1`
- **GitLab, Jenkins, Azure Pipelines, Bitbucket** และอื่น ๆ: ติดตั้ง `cosec-cli` บน runner ด้วยวิธีใดวิธีหนึ่งข้างบน
  (pin เวอร์ชันใน runner image) แล้วดูตัวอย่างสำเร็จรูปใน [คู่มือ CI](https://cosec-shield.epicprosmart.com/#/help/ci)

คำสั่งอื่น: `cosec-cli case <slug>`, `cosec-cli audit verify|decrypt`, `cosec-cli mcp connect|bridge|status`, `cosec-cli -h`

## อัปเดต

```sh
cosec-cli update --check          # เทียบกับ release ล่าสุดที่นี่ แล้วบอกคำสั่งอัปเกรดของ OS นั้น
```

การเช็กนี้คือการเรียก network ครั้งเดียวที่ `cosec-cli` ทำเอง และทำเฉพาะเมื่อสั่ง binary ไม่ดาวน์โหลดหรือแทนที่ตัวเอง
อัปเกรดด้วย `brew upgrade cosec-cli`, `scoop update cosec-cli`, สคริปต์ติดตั้ง หรือแพ็กเกจรุ่นใหม่

## ถอนการติดตั้ง

| ติดตั้งด้วย | วิธีลบ |
|---|---|
| Homebrew | `brew uninstall cosec-cli` |
| Scoop | `scoop uninstall cosec-cli` |
| install.sh / ด้วยมือ | `rm /usr/local/bin/cosec-cli` (หรือ `~/.local/bin/cosec-cli`) |
| install.ps1 / ด้วยมือ | ลบโฟลเดอร์ `%LOCALAPPDATA%\Programs\cosec-cli` และเอาออกจาก PATH ของผู้ใช้ |
| deb / rpm | `sudo dpkg -r cosec-cli` / `sudo rpm -e cosec-cli` |

profile และ key ของ MCP อยู่ใน `~/.config/cosec-cli/` และ keychain ของ OS; `cosec-cli mcp disconnect` ลบให้

## สัญญาอนุญาต

สัญญาอนุญาตใช้ binary แบบ proprietary ดู [LICENSE.md](LICENSE.md) ส่วนประกอบ open source อยู่ใน SBOM ที่แนบกับแต่ละ release
