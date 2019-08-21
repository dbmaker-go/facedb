package main

import (
	"database/sql"
	"fmt"

	_ "github.com/dbmaker-go/dbmaker"
)

type Person struct {
	Id   int
	Name string
	Dist float64
}

var mydb *sql.DB

func openDb() (*sql.DB, error) {
	if mydb != nil {
		return mydb, nil
	}
	cnstr := fmt.Sprintf("DSN=%s;UID=SYSADM;PWD=;PTNUM=%s;SVADR=%s", dbname, dbptnum, dbsvadr)
	if db, err := sql.Open("dbmaker", cnstr); err != nil {
		return nil, err
	} else {
		mydb = db
	}
	return mydb, nil
}

func dbSearchFace(img []byte, minDist float32) (person Person, found bool, oerr error) {
	var db *sql.DB
	var err error
	if db, err = openDb(); err != nil {
		return Person{}, false, err
	}
	//defer db.Close()

	sql := ` select id, name, sp.odist as distance from faces 
	join (call annoy_get('faces','idxvec',getfacevector2(?),128,5)) as sp 
	on faces.id = sp.orid where distance <= ?
	`
	sql = "execute command getface5(?,?)"

	if rows, err := db.Query(sql, img, minDist); err != nil {
		return Person{}, false, err
	} else {
		defer rows.Close()

		var p Person
		if rows.Next() {
			rows.Scan(&p.Id, &p.Name, &p.Dist)
			return p, true, nil
		} else {
			return p, false, nil
		}
	}
}

func dbInsFace(name string, img []byte) (p Person, oerr error) {
	var db *sql.DB
	var err error
	if db, err = openDb(); err != nil {
		return Person{}, err
	}
	//defer db.Close()
	sql := "insert into faces(name, photo) values(?,?)"
	if rs, err := db.Exec(sql, name, img); err != nil {
		return Person{}, err
	} else if nins, _ := rs.RowsAffected(); nins > 0 {
		sql = "select LAST_SERIAL from SYSCONINFO"
		if rows, err := db.Query(sql); err != nil {
			return Person{}, err
		} else {
			defer rows.Close()
			if rows.Next() {
				rows.Scan(&p.Id)
				p.Name = name

				// update index
				dbUpdateAnnoyIdx()

				return p, nil
			}
			return Person{}, nil
		}
	}
	return Person{}, nil
}

func dbUpdateAnnoyIdx() error {
	if db, err := openDb(); err != nil {
		return err
	} else {
		var nItem int
		if _, err := db.Exec("call annoy_create('faces','idxvec','id','vector', 128, ?);", &nItem); err != nil {
			return err
		}
		fmt.Printf("update annoy index: %d\n", nItem)
	}
	return nil
}

func dbGetPhoto(id int) ([]byte, error) {
	if db, err := openDb(); err != nil {
		return nil, err
	} else {
		sql := "select photo from faces where id = ?"
		if rows, err := db.Query(sql, id); err != nil {
			return nil, err
		} else {
			defer rows.Close()
			if rows.Next() {
				var photo []byte
				rows.Scan(&photo)

				return photo, nil
			}
			return nil, nil
		}
	}
}
