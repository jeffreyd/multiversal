#!/usr/bin/env python3
"""
CBR to CBZ/CB7 Converter

Converts Comic Book RAR (.cbr) files to Comic Book ZIP (.cbz) or Comic Book 7z (.cb7) files.
This tool extracts CBR files using the system 'unrar' command and
repackages them as ZIP or 7z files.

Usage:
    python cbr_to_cbz.py <input_file_or_directory> [options]

Examples:
    python cbr_to_cbz.py comic.cbr
    python cbr_to_cbz.py comic.cbr --format cb7
    python cbr_to_cbz.py /path/to/comics/ --format cbz
    python cbr_to_cbz.py comics/ --recursive --delete-original --format cb7
"""

import os
import sys
import argparse
import tempfile
import shutil
import zipfile
import subprocess
from pathlib import Path
from typing import List, Optional
from enum import Enum


class OutputFormat(Enum):
    """Supported output formats."""
    CBZ = "cbz"
    CB7 = "cb7"


class CbrConverter:
    def __init__(self, output_format: OutputFormat = OutputFormat.CBZ, delete_original: bool = False, verbose: bool = False):
        self.output_format = output_format
        self.delete_original = delete_original
        self.verbose = verbose
        self.converted_count = 0
        self.failed_count = 0

    def log(self, message: str) -> None:
        """Print message if verbose mode is enabled."""
        if self.verbose:
            print(f"[INFO] {message}")

    def error(self, message: str) -> None:
        """Print error message."""
        print(f"[ERROR] {message}", file=sys.stderr)

    def check_unrar_available(self) -> bool:
        """Check if unrar command is available."""
        try:
            result = subprocess.run(['unrar'], capture_output=True, text=True)
            return result.returncode != 127  # 127 = command not found
        except FileNotFoundError:
            return False

    def check_7z_available(self) -> bool:
        """Check if 7z command is available."""
        try:
            result = subprocess.run(['7z'], capture_output=True, text=True)
            return result.returncode != 127  # 127 = command not found
        except FileNotFoundError:
            return False

    def is_cbr_file(self, file_path: Path) -> bool:
        """Check if file is a CBR file."""
        return file_path.suffix.lower() == '.cbr' and file_path.is_file()

    def extract_cbr(self, cbr_path: Path, extract_dir: Path) -> bool:
        """Extract CBR file to directory using unrar."""
        try:
            self.log(f"Extracting {cbr_path.name}...")

            # Use unrar to extract files
            cmd = ['unrar', 'e', '-o+', str(cbr_path), str(extract_dir)]
            result = subprocess.run(cmd, capture_output=True, text=True)

            if result.returncode != 0:
                self.error(f"Failed to extract {cbr_path.name}: {result.stderr}")
                return False

            # Check if any files were extracted
            extracted_files = list(extract_dir.iterdir())
            if not extracted_files:
                self.error(f"No files extracted from {cbr_path.name}")
                return False

            self.log(f"Extracted {len(extracted_files)} files")
            return True

        except Exception as e:
            self.error(f"Exception while extracting {cbr_path.name}: {e}")
            return False

    def create_archive(self, source_dir: Path, output_path: Path) -> bool:
        """Create archive file (CBZ or CB7) from extracted files."""
        if self.output_format == OutputFormat.CBZ:
            return self._create_cbz(source_dir, output_path)
        elif self.output_format == OutputFormat.CB7:
            return self._create_cb7(source_dir, output_path)
        else:
            self.error(f"Unsupported output format: {self.output_format}")
            return False

    def _create_cbz(self, source_dir: Path, cbz_path: Path) -> bool:
        """Create CBZ file from extracted files."""
        try:
            self.log(f"Creating {cbz_path.name}...")

            # Get all image files, sorted naturally
            image_files = self._get_image_files(source_dir)
            if not image_files:
                return False

            # Create ZIP file
            with zipfile.ZipFile(cbz_path, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as zip_file:
                for image_file in image_files:
                    zip_file.write(image_file, image_file.name)

            self.log(f"Created CBZ with {len(image_files)} images")
            return True

        except Exception as e:
            self.error(f"Exception while creating {cbz_path.name}: {e}")
            return False

    def _create_cb7(self, source_dir: Path, cb7_path: Path) -> bool:
        """Create CB7 file from extracted files using 7z command."""
        try:
            self.log(f"Creating {cb7_path.name}...")

            # Get all image files, sorted naturally
            image_files = self._get_image_files(source_dir)
            if not image_files:
                return False

            # Use 7z to create archive with high compression
            cmd = ['7z', 'a', '-t7z', '-mx=9', str(cb7_path)] + [str(f) for f in image_files]
            result = subprocess.run(cmd, capture_output=True, text=True, cwd=source_dir)

            if result.returncode != 0:
                self.error(f"Failed to create {cb7_path.name}: {result.stderr}")
                return False

            self.log(f"Created CB7 with {len(image_files)} images")
            return True

        except Exception as e:
            self.error(f"Exception while creating {cb7_path.name}: {e}")
            return False

    def _get_image_files(self, source_dir: Path) -> List[Path]:
        """Get all image files from directory, sorted naturally."""
        image_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.tiff', '.tga'}
        image_files = []

        for file_path in source_dir.iterdir():
            if file_path.is_file() and file_path.suffix.lower() in image_extensions:
                image_files.append(file_path)

        if not image_files:
            self.error(f"No image files found in extracted content")
            return []

        # Sort files naturally (page001.jpg, page002.jpg, etc.)
        image_files.sort(key=lambda x: x.name.lower())
        return image_files

    def convert_file(self, cbr_path: Path) -> bool:
        """Convert a single CBR file to the specified output format."""
        if not self.is_cbr_file(cbr_path):
            self.error(f"{cbr_path.name} is not a CBR file")
            return False

        # Create output path with appropriate extension
        output_suffix = f'.{self.output_format.value}'
        output_path = cbr_path.with_suffix(output_suffix)

        # Check if output file already exists
        if output_path.exists():
            self.log(f"{self.output_format.value.upper()} already exists: {output_path.name}, skipping...")
            return True

        print(f"Converting: {cbr_path.name} -> {output_path.name}")

        # Create temporary directory for extraction
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)

            # Extract CBR
            if not self.extract_cbr(cbr_path, temp_path):
                self.failed_count += 1
                return False

            # Create output archive
            if not self.create_archive(temp_path, output_path):
                self.failed_count += 1
                # Clean up partial output file
                if output_path.exists():
                    output_path.unlink()
                return False

        # Verify output file was created successfully
        if not output_path.exists() or output_path.stat().st_size == 0:
            self.error(f"Failed to create valid {self.output_format.value.upper()} file: {output_path.name}")
            self.failed_count += 1
            return False

        # Delete original if requested
        if self.delete_original:
            try:
                cbr_path.unlink()
                self.log(f"Deleted original: {cbr_path.name}")
            except Exception as e:
                self.error(f"Failed to delete original {cbr_path.name}: {e}")

        self.converted_count += 1
        print(f"✓ Successfully converted: {output_path.name}")
        return True

    def find_cbr_files(self, path: Path, recursive: bool = False) -> List[Path]:
        """Find all CBR files in a directory."""
        cbr_files = []

        if path.is_file():
            if self.is_cbr_file(path):
                cbr_files.append(path)
        elif path.is_dir():
            if recursive:
                # Recursive search
                for cbr_file in path.rglob("*.cbr"):
                    if cbr_file.is_file():
                        cbr_files.append(cbr_file)
            else:
                # Only current directory
                for cbr_file in path.glob("*.cbr"):
                    if cbr_file.is_file():
                        cbr_files.append(cbr_file)

        return sorted(cbr_files)

    def convert_path(self, input_path: Path, recursive: bool = False) -> None:
        """Convert CBR files in given path."""
        cbr_files = self.find_cbr_files(input_path, recursive)

        if not cbr_files:
            print("No CBR files found.")
            return

        print(f"Found {len(cbr_files)} CBR file(s) to convert...")

        for cbr_file in cbr_files:
            try:
                self.convert_file(cbr_file)
            except KeyboardInterrupt:
                print("\n[INTERRUPTED] Conversion stopped by user")
                break
            except Exception as e:
                self.error(f"Unexpected error converting {cbr_file.name}: {e}")
                self.failed_count += 1

        # Print summary
        print(f"\nConversion Summary:")
        print(f"  Successfully converted: {self.converted_count}")
        print(f"  Failed: {self.failed_count}")
        print(f"  Total processed: {self.converted_count + self.failed_count}")


def main():
    parser = argparse.ArgumentParser(
        description="Convert CBR (Comic Book RAR) files to CBZ (Comic Book ZIP) or CB7 (Comic Book 7z) format",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s comic.cbr                         # Convert single file to CBZ (default)
  %(prog)s comic.cbr --format cb7            # Convert single file to CB7
  %(prog)s comics/                           # Convert all CBR files in directory to CBZ
  %(prog)s comics/ --format cb7              # Convert all CBR files in directory to CB7
  %(prog)s comics/ -r                        # Convert recursively in subdirectories
  %(prog)s comics/ -r --delete-original      # Convert and delete original CBR files
  %(prog)s comics/ -v --format cb7           # Verbose output, convert to CB7
        """
    )

    parser.add_argument(
        'input_path',
        help='CBR file or directory containing CBR files'
    )

    parser.add_argument(
        '-f', '--format',
        choices=['cbz', 'cb7'],
        default='cbz',
        help='Output format: cbz (ZIP) or cb7 (7z). Default: cbz'
    )

    parser.add_argument(
        '-r', '--recursive',
        action='store_true',
        help='Search for CBR files recursively in subdirectories'
    )

    parser.add_argument(
        '--delete-original',
        action='store_true',
        help='Delete original CBR files after successful conversion'
    )

    parser.add_argument(
        '-v', '--verbose',
        action='store_true',
        help='Enable verbose output'
    )

    args = parser.parse_args()

    # Validate input path
    input_path = Path(args.input_path)
    if not input_path.exists():
        print(f"Error: Path does not exist: {input_path}", file=sys.stderr)
        sys.exit(1)

    # Parse output format
    output_format = OutputFormat.CBZ if args.format == 'cbz' else OutputFormat.CB7

    # Create converter
    converter = CbrConverter(
        output_format=output_format,
        delete_original=args.delete_original,
        verbose=args.verbose
    )

    # Check if unrar is available
    if not converter.check_unrar_available():
        print("Error: 'unrar' command not found. Please install unrar.", file=sys.stderr)
        print("  On Ubuntu/Debian: sudo apt install unrar", file=sys.stderr)
        print("  On macOS: brew install unrar", file=sys.stderr)
        print("  On Fedora: sudo dnf install unrar", file=sys.stderr)
        sys.exit(1)

    # Check if 7z is available when CB7 format is requested
    if output_format == OutputFormat.CB7 and not converter.check_7z_available():
        print("Error: '7z' command not found. Please install p7zip.", file=sys.stderr)
        print("  On Ubuntu/Debian: sudo apt install p7zip-full", file=sys.stderr)
        print("  On macOS: brew install p7zip", file=sys.stderr)
        print("  On Fedora: sudo dnf install p7zip", file=sys.stderr)
        sys.exit(1)

    try:
        converter.convert_path(input_path, args.recursive)
    except KeyboardInterrupt:
        print("\n[INTERRUPTED] Conversion stopped by user")
        sys.exit(1)

    # Exit with error code if any conversions failed
    if converter.failed_count > 0:
        sys.exit(1)


if __name__ == '__main__':
    main()