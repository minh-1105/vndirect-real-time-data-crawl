
import sys

from snapshot import main as snapshot_main


def main():
    symbols = sys.argv[1:] or ["VND", "AAA"]
    snapshot_main([symbol.upper() for symbol in symbols])


if __name__ == "__main__":
    main()
