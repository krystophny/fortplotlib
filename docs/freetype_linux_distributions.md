# FreeType Detection on Linux Distributions

This document describes how FreeType detection works on different Linux distributions and how to test it.

## Overview

The FreeType detection system supports multiple Linux distributions by checking various standard library paths and using pkg-config when available.

## Distribution-Specific Paths

### Debian/Ubuntu
- **Package**: `libfreetype6-dev` (development), `libfreetype6` (runtime)
- **Library paths**: `/usr/lib/x86_64-linux-gnu`, `/usr/lib/i386-linux-gnu`, `/usr/lib`
- **pkg-config**: Available as `freetype2`

Installation:
```bash
sudo apt-get install libfreetype6-dev pkg-config
```

### RedHat/CentOS/Fedora
- **Package**: `freetype-devel` (development), `freetype` (runtime)
- **Library paths**: `/usr/lib64`, `/usr/lib`, `/lib64`, `/lib`
- **pkg-config**: Available as `freetype2`

Installation:
```bash
# RedHat/CentOS
sudo yum install freetype-devel pkgconfig
# or
sudo dnf install freetype-devel pkgconfig

# Fedora
sudo dnf install freetype-devel pkgconfig
```

### Arch Linux
- **Package**: `freetype2`
- **Library paths**: `/usr/lib`, `/usr/local/lib`
- **pkg-config**: Available as `freetype2`

Installation:
```bash
sudo pacman -S freetype2 pkgconf
```

### Alpine Linux
- **Package**: `freetype-dev` (development), `freetype` (runtime)
- **Library paths**: `/usr/lib`, `/lib`, `/usr/local/lib`
- **pkg-config**: Available as `freetype2`

Installation:
```bash
sudo apk add freetype-dev pkgconfig
```

### SUSE/openSUSE
- **Package**: `freetype2-devel` (development), `libfreetype6` (runtime)
- **Library paths**: `/usr/lib64`, `/usr/lib`, `/lib64`, `/lib`
- **pkg-config**: Available as `freetype2`

Installation:
```bash
sudo zypper install freetype2-devel pkg-config
```

### Gentoo
- **Package**: `media-libs/freetype`
- **Library paths**: `/usr/lib64`, `/usr/lib`, `/usr/local/lib64`, `/usr/local/lib`
- **pkg-config**: Available as `freetype2`

Installation:
```bash
sudo emerge media-libs/freetype dev-util/pkgconfig
```

## Testing on Different Distributions

### Using Docker

You can test FreeType detection on different distributions using Docker:

```bash
# Ubuntu/Debian
docker run -it --rm -v $(pwd):/work ubuntu:22.04 bash
apt-get update && apt-get install -y gfortran make libfreetype6-dev pkg-config
cd /work && make test ARGS="--target test_freetype_pkg_config"

# CentOS/RHEL
docker run -it --rm -v $(pwd):/work centos:8 bash
yum install -y gcc-gfortran make freetype-devel pkgconfig
cd /work && make test ARGS="--target test_freetype_pkg_config"

# Alpine
docker run -it --rm -v $(pwd):/work alpine:latest sh
apk add gfortran make freetype-dev pkgconfig
cd /work && make test ARGS="--target test_freetype_pkg_config"

# Arch Linux
docker run -it --rm -v $(pwd):/work archlinux:latest bash
pacman -Sy --noconfirm gcc-fortran make freetype2 pkgconf
cd /work && make test ARGS="--target test_freetype_pkg_config"
```

### Using Virtual Machines

For more comprehensive testing, you can use virtual machines:

1. **VirtualBox/VMware**: Set up VMs with different distributions
2. **Cloud providers**: Use AWS, GCP, or Azure instances
3. **GitHub Actions**: The CI/CD pipeline already tests on Ubuntu

### Manual Testing Commands

On each distribution, run these commands to verify FreeType detection:

```bash
# Check if pkg-config finds FreeType
pkg-config --exists freetype2 && echo "pkg-config: OK" || echo "pkg-config: FAILED"

# Check library paths
pkg-config --libs-only-L freetype2

# Check version
pkg-config --modversion freetype2

# Test our detection
make test ARGS="--target test_freetype_pkg_config"
make test ARGS="--target test_freetype_dynamic_loading"
make example ARGS="backend_selection_demo"
```

## Troubleshooting

### Common Issues

1. **pkg-config not found**: Install the pkg-config package
2. **FreeType not found**: Install the FreeType development package
3. **Library path issues**: Check `/etc/ld.so.conf` and run `ldconfig`
4. **Permission issues**: Make sure you have read access to library files

### Debug Information

Use these commands to debug FreeType detection issues:

```bash
# Check if FreeType library exists
find /usr -name "libfreetype*" 2>/dev/null

# Check dynamic linker paths
ldconfig -p | grep freetype

# Check pkg-config paths
pkg-config --variable=libdir freetype2

# Test dynamic loading
ldd /usr/lib/x86_64-linux-gnu/libfreetype.so.6
```

## CI/CD Integration

The GitHub Actions workflow automatically tests on:
- Ubuntu (multiple gfortran versions)
- macOS (with Homebrew)

To add more distributions to CI/CD:

1. Add new matrix entries to `.github/workflows/ci.yml`
2. Specify the correct package installation commands
3. Test the FreeType detection tests

## Library Names by Distribution

| Distribution | Library Name | Development Package |
|-------------|-------------|-------------------|
| Debian/Ubuntu | `libfreetype.so.6` | `libfreetype6-dev` |
| RedHat/CentOS | `libfreetype.so.6` | `freetype-devel` |
| Arch Linux | `libfreetype.so.6` | `freetype2` |
| Alpine | `libfreetype.so.6` | `freetype-dev` |
| SUSE | `libfreetype.so.6` | `freetype2-devel` |
| Gentoo | `libfreetype.so.6` | `media-libs/freetype` |

## Performance Considerations

- pkg-config detection is fastest and most reliable
- File system checks are slower but work without pkg-config
- Dynamic loading verification is most thorough but slowest

The detection system tries methods in order of reliability and speed:
1. pkg-config (fastest, most reliable)
2. Standard system paths (fast, good coverage)
3. macOS-specific paths (for macOS)
4. Windows paths (for Windows)