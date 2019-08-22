package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
)

var webroot string = "n:/prj/facerecog/facewebgo"
var imgroot string = "n:/prj/facerecog/faceimg"
var faceserver string = "127.0.0.1:9999"
var dbsvadr string = "127.0.0.1"
var dbptnum string = "20001"
var dbname string = "FACEDB"

func main() {
	defer func() {
		dbClose()
	}()

	var port string
	var wroot string
	var httpEnabled bool

	flag.StringVar(&wroot, "r", "", "web root dir")
	flag.StringVar(&port, "p", "9090", "listen port number")
	flag.BoolVar(&httpEnabled, "s", false, "enable http?")
	flag.StringVar(&dbsvadr, "dbsvadr", dbsvadr, "db_svadr")
	flag.StringVar(&dbptnum, "dbptnum", dbptnum, "db_ptnum")
	flag.StringVar(&dbname, "dbname", dbname, "facedb name")
	flag.Parse()

	if wroot == "" {
		wroot = filepath.Dir(os.Args[0])
		//wroot, _ = os.Getwd()
	}
	if dir, err := filepath.Abs(wroot); err != nil {
		fmt.Println("get web root dir fail:", err)
		return
	} else {
		webroot = dir
	}

	webroot = strings.Replace(webroot, "\\", "/", -1)
	//imgroot = strings.Replace(imgroot, "\\", "/", -1)

	fmt.Printf("web root: %s\n", webroot)
	//fmt.Printf("img root: %s\n", imgroot)
	fmt.Printf("Access db: %s:%s/%s\n", dbsvadr, dbptnum, dbname)

	fsh := http.FileServer(http.Dir(webroot))
	//imgFh := http.FileServer(http.Dir(imgroot))

	http.HandleFunc("/", index)
	http.Handle("/static/", fsh)
	//http.Handle("/registered/", imgFh)

	http.HandleFunc("/hello", HelloServer)
	http.HandleFunc("/search", searchFace)
	http.HandleFunc("/register", registerFace)
	http.HandleFunc("/getphoto", getPhoto)
	http.HandleFunc("/allfaces", showFaces)

	if httpEnabled {
		fmt.Printf("face web server is listening on http://*:%s\n", port)
		log.Fatal(http.ListenAndServe(":"+port, nil))
	} else {
		fmt.Printf("face web server is listening on https://*:%s\n", port)
		log.Fatal(http.ListenAndServeTLS(":"+port, filepath.Join(wroot, "server.crt"),
			filepath.Join(wroot, "server.key"), nil))
	}

}

// hello world, the web server
func HelloServer(w http.ResponseWriter, req *http.Request) {
	io.WriteString(w, "hello, world!\n")
}

func index(w http.ResponseWriter, req *http.Request) {
	fmt.Println("=========/ : Get=============")
	fmt.Printf("User-Agent: %v\n", req.UserAgent())
	http.Redirect(w, req, "/static/camera.html", http.StatusFound)
}

func getCurDir() string {
	path, err := filepath.Abs(filepath.Dir(os.Args[0]))
	if err != nil {
		panic(err)
	}
	return path
}
