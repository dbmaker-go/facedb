package main

import (
	"encoding/base64"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
)

func searchFace(w http.ResponseWriter, req *http.Request) {
	defer func() {
		if xerr := recover(); xerr != nil {
			msg := fmt.Sprintf("%v", xerr)
			replyErr(w, msg)
		}
	}()

	log.Printf("======/search: %v =====\n", req.Method)
	b64img := req.PostFormValue("img")
	if b64img == "" {
		replyErr(w, "not found image")
		return
	}
	// data:image/png;base64,
	start := strings.Index(b64img, "base64,")
	if start <= 0 || start+7 >= len(b64img) {
		replyErr(w, "invalid image header")
		return
	}
	imgbuf := b64img[start+7:]
	img, err := base64.StdEncoding.DecodeString(imgbuf)
	if err != nil {
		replyErr(w, "invalid image:"+err.Error())
		return
	}

	person, found, err := dbSearchFace(img, 0.38)
	if err != nil {
		replyErr(w, "query error:"+err.Error())
		return
	}

	if !found {
		replyRecogNot(w)
		return
	}

	replyOK(w, person)
	return
}

func replyErr(w http.ResponseWriter, msg string) {
	msg = `{"code":1,"error":"` + msg + `"}`
	fmt.Println("reply:", msg)
	io.WriteString(w, msg)
}
func replyOK(w http.ResponseWriter, p Person) {
	msg := fmt.Sprintf(`{"code":0,"data":{"faceid":"%d", "name":"%v", "dis":%f}}`,
		p.Id, p.Name, p.Dist)
	fmt.Println("reply:", msg)
	io.WriteString(w, msg)
}
func replyRecogNot(w http.ResponseWriter) {
	msg := fmt.Sprintf(`{"code":102, "error":"抱歉，不认识您"}`)
	fmt.Println("reply:", msg)
	io.WriteString(w, msg)
}
func replyNoFace(w http.ResponseWriter) {
	msg := fmt.Sprintf(`{"code":101, "error":"no face"}`)
	fmt.Println("reply:", msg)
	io.WriteString(w, msg)
}
