# Copyright © 2022 Kris Nóva <kris@nivenly.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ███╗   ██╗ ██████╗ ██╗   ██╗ █████╗
# ████╗  ██║██╔═████╗██║   ██║██╔══██╗
# ██╔██╗ ██║██║██╔██║██║   ██║███████║
# ██║╚██╗██║████╔╝██║╚██╗ ██╔╝██╔══██║
# ██║ ╚████║╚██████╔╝ ╚████╔╝ ██║  ██║
# ╚═╝  ╚═══╝ ╚═════╝   ╚═══╝  ╚═╝  ╚═╝
#
TARGET  := boopkit
CFLAGS  ?= -I/usr/local/include
LDFLAGS ?= ""
LIBS     = -lxdp -lbpf -lelf
STYLE    = Google

all: pr0be skeleton build ## Build everything

.PHONY: clean
clean: ## Clean objects
	rm -vf $(TARGET)
	rm -vf *.o
	rm -vf *.ll
	rm -vf pr0be.skel*
	rm -vf vmlinux.h

.PHONY: boop
boop:  ## Build trigger program
	@echo "  ->  Building trigger program"
	cd boop && make

skeleton: pr0be ## Generate eBPF dynamic skeleton headers
	@echo "  ->  Generating pr0be.skel.safe.h"
	bpftool gen skeleton pr0be.safe.o -p > pr0be.skel.safe.h
	bpftool gen skeleton pr0be.xdp.o -p > pr0be.skel.xdp.h


format: ## Format the code
	@echo "  ->  Formatting code"
	@clang-format -i -style=$(STYLE) *.c *.h
	@clang-format -i -style=$(STYLE) boop/*.c boop/*.h

build: boop ## Build boopkit userspace program
	@echo "  ->  Building boopkit"
	clang $(CFLAGS) $(LDFLAGS) -o $(TARGET) boopkit.c common.c dpi.c -Wl, $(LIBS)

install: ## Install boopkit to /usr/bin/boopkit
	cp $(TARGET) /usr/bin/$(TARGET)
	cp boop/boopkit-boop /usr/bin/boopkit-boop
	@mkdir -p ${HOME}/.boopkit
	cp pr0be.safe.o ${HOME}/.boopkit/pr0be.safe.o
	cp pr0be.boop.o ${HOME}/.boopkit/pr0be.boop.o
	cp pr0be.xdp.o ${HOME}/.boopkit/pr0be.xdp.o


.PHONY: pr0be
pr0be: autogen pr0be.boop.o pr0be.safe.o pr0be.xdp.o ## Compile eBPF probes
	@echo "  ->  Building eBPF pr0bes"

autogen:
	bpftool btf dump file /sys/kernel/btf/vmlinux format c > vmlinux.h

pr0be.boop.o: pr0be.boop.c
	@echo "  ->  Building pr0be.boop.o"
	clang -S \
	    -target bpf \
	    -D __BPF_TRACING__ \
	    $(CFLAGS) \
	    -Wall \
	    -Werror \
	    -O2 -emit-llvm -c -g pr0be.boop.c
	llc -march=bpf -filetype=obj -o pr0be.boop.o pr0be.boop.ll

pr0be.safe.o: pr0be.safe.c
	@echo "  ->  Building pr0be.safe.o"
	clang -S \
	    -target bpf \
	    -D __BPF_TRACING__ \
	    $(CFLAGS) \
	    -Wall \
	    -Werror \
	    -O2 -emit-llvm -c -g pr0be.safe.c
	llc -march=bpf -filetype=obj -o pr0be.safe.o pr0be.safe.ll

pr0be.xdp.o: pr0be.xdp.c
	@echo "  ->  Building pr0be.xdp.o"
	clang -S \
	    -target bpf \
	    -D __BPF_TRACING__ \
	    $(CFLAGS) \
	    -Wall \
	    -Werror \
	    -O2 -emit-llvm -c -g pr0be.xdp.c
	llc -march=bpf -filetype=obj -o pr0be.xdp.o pr0be.xdp.ll


.PHONY: help
help:  ## Show help messages for make targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}'
