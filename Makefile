CC 	:= cc
CFLAGS 	:= -shared -fPIC -Isrc

NAME	:= portfile
LIB 	:= libtree-sitter-$(NAME).so

SRC	:= src/parser.c src/scanner.c
BUILD	:= build
TARGET	:= $(BUILD)/$(LIB)

EMACS_TREESIT 	:= $(HOME)/.emacs.d/tree-sitter
EMACS_TARGET	:= $(EMACS_TREESIT)/$(LIB)

.PHONY: all build test clean emacs

all: build

build: $(TARGET)

$(TARGET): $(SRC)
	@mkdir -p $(BUILD)
	$(CC) $(CFLAGS) $(SRC) -o $@

test:
	tree-sitter test

emacs: build
	@mkdir -p $(EMACS_TREESIT)
	cp $(TARGET) $(EMACS_TARGET)
	@echo "Installed $(EMACS_TARGET)"

clean:
	rm -rf $(BUILD)
