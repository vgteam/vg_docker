#!/usr/bin/env bash
git add vg
git commit -m "vg $(git -C vg rev-parse HEAD)"

