# =====================================================================
# Proyecto:    TransTijuana OTP — Logística de Personas (Tema 24)
# Autor:       Axel Tadeo Daniels Ceballos
# Curso:       Programación Lógica y Funcional (TecNM Campus Tijuana)
# =====================================================================

ERLC = erlc
ERL = erl
INCDIR = include
SRCDIR = src
TESTDIR = test
EBINDIR = ebin

ERLC_FLAGS = -I $(INCDIR) -o $(EBINDIR) +debug_info

SOURCES = $(wildcard $(SRCDIR)/*.erl)
TESTS = $(wildcard $(TESTDIR)/*.erl)
BEAMS = $(SOURCES:$(SRCDIR)/%.erl=$(EBINDIR)/%.beam)

.PHONY: all compile test run clean dirs

all: compile

dirs:
	@mkdir -p $(EBINDIR)

compile: dirs $(BEAMS)
	@cp -f $(SRCDIR)/logistica.app $(EBINDIR)/ 2>/dev/null || true
	@echo "==> Compilación finalizada exitosamente en $(EBINDIR)/"

$(EBINDIR)/%.beam: $(SRCDIR)/%.erl
	$(ERLC) $(ERLC_FLAGS) $<

test: dirs compile
	@echo "==> Compilando y ejecutando suite EUnit..."
	@$(ERLC) -DTEST -I $(INCDIR) -o $(EBINDIR) $(TESTDIR)/logistica_tests.erl
	@$(ERL) -pa $(EBINDIR) -eval 'case eunit:test(logistica_tests, [verbose]) of ok -> halt(0); _ -> halt(1) end.' -noshell

run: compile
	@echo "==> Iniciando TransTijuana OTP en http://localhost:8080..."
	@$(ERL) -pa $(EBINDIR) -eval 'application:start(sasl), application:start(logistica).'

clean:
	@rm -rf $(EBINDIR)/*.beam $(EBINDIR)/logistica.app $(SRCDIR)/*.beam
	@echo "==> Archivos binarios .beam eliminados."
