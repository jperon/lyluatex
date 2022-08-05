test:
	TEXINPUTS=luaoptions: lualatex -interaction=nonstopmode -shell-escape test.tex

manual:
	@lua -e "if tonumber(io.popen('pandoc -v'):read():gsub('pandoc (.*)', '%1'):sub(1,1)) < 2 then print('Pandoc >= 2 required') ; os.exit(1) ; end"
	pandoc -s -V fontfamily=libertine --toc-depth=4 -o lyluatex-tmp.tex lyluatex.md
	@echo Inserting examples
	@./insert-examples.lua lyluatex-tmp.tex lyluatex.tex || echo "Lua not found. Please make sure it's accessible in your PATH."
	TEXINPUTS=luaoptions: latexmk lyluatex

clean:
	git clean -fXd

ctan: manual
	mkdir -p ./ctan/lyluatex/ly
	cp -R lyluatex.sty lyluatex*.lua \
		latexmkrc lyluatexbase.cls lyluatexmanual.cls \
		lyluatex.tex lyluatex.pdf LICENSE Contributors.md \
		./ctan/lyluatex/
	cp ly/*.ly ./ctan/lyluatex/ly/
	echo 'Main author: [Fr. Jacques Peron](mailto:cataclop@hotmail.com)\nThis material is subject to the MIT license.\n' \
		> ./ctan/lyluatex/README.md
	echo '# Lyluatex' >> ./ctan/lyluatex/README.md
	sed -n -e '/## Usage/,$$p' README.md | sed '/test.en.tex/d' >> ./ctan/lyluatex/README.md
	(cd ctan/ ; zip -r lyluatex lyluatex)
