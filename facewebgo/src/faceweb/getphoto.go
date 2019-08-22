package main

import (
	"fmt"
	"html/template"
	"log"
	"net/http"
	"strconv"
)

func getPhoto(w http.ResponseWriter, req *http.Request) {
	defer func() {
		if xerr := recover(); xerr != nil {
			msg := fmt.Sprintf("%v", xerr)
			replyErr(w, msg)
		}
	}()

	log.Printf("======/getphoto: %v =====\n", req.Method)

	idstr := req.FormValue("id")
	if idstr == "" {
		fmt.Printf("no id from client\n")
		w.Write([]byte(""))
		return
	}
	id, _ := strconv.ParseInt(idstr, 10, 32)

	photo, err := dbGetPhoto(int(id))
	if err != nil {
		fmt.Printf("can not get photo from face db: %v\n", err)
		w.Write([]byte(""))
		return
	}

	w.Header().Set("Content-Type", "image/jpeg")
	w.Write(photo)
	return
}

func showFaces(w http.ResponseWriter, req *http.Request) {
	defer func() {
		if xerr := recover(); xerr != nil {
			msg := fmt.Sprintf("%v", xerr)
			replyErr(w, msg)
		}
	}()

	log.Printf("======/allfaces: %v =====\n", req.Method)

	faces, err := dbGetAllFaces()
	if err != nil {
		msg := fmt.Sprintf("can not get faces from face db: %v\n", err)
		replyErr(w, msg)
		return
	} else {
		if t, err := template.ParseFiles("static/test/allfaces.html"); err != nil {
			replyErr(w, err.Error())
			return
		} else {
			if err = t.Execute(w, faces); err != nil {
				replyErr(w, err.Error())
				return
			}
			//io.WriteString(w, "<br>OK")
		}
	}

	return
}
