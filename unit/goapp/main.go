package main

import (
    "io"
    "net/http"
    "path"
    "unit.nginx.org/go"
    "strings"
    "os"
)

func main() {
    http.HandleFunc("/docs",func (w http.ResponseWriter, r *http.Request) {
	pages, ok := r.URL.Query()["page"]
	if !ok || len(pages) < 1 {
		index, err := os.Open("/projects/unit/goapp/docs/index.html")
		if err != nil {
			w.Write([]byte("Can't open index"))
			return
		}
		defer index.Close()
		io.Copy(w, index)
		return
	}
	page := pages[0]
	cleanPath := path.Clean("/projects/unit/goapp/docs/" + page)
	if strings.Contains(cleanPath, "..") {
		w.Write([]byte("Please stop hacking!"))
		return
	}
	file, err := os.Open(cleanPath)
	if err != nil {
		w.Write([]byte("Can't open file"))
		return
	}
	defer file.Close()
	io.Copy(w, file)
    })
    unit.ListenAndServe(":81", nil)
}
