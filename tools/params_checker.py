#!/usr/bin/env python3

import argparse
import json

def check_params(params_file) -> bool:
    # TODO implement parameters check
    pass

def main():
    args_parser = argparse.ArgumentParser()

    args_parser.add_argument("--input", required=True)
    args_parser.add_argument("--output", required=True)

    args = args_parser.parse_args()

    with open(args.input, mode="r", encoding="utf-8") as source:
        params_file = json.load(source)

    check_params(params_file)

    with open(args.output, mode="w", encoding="utf-8") as destination:
        json.dump(params_file, destination, indent=2, sort_keys=True)
        destination.write("\n")

if __name__ == "__main__":
    main()