// Generated by wangdxh
package snmplib

import (
	"encoding/hex"
	"fmt"
	"github.com/soniah/gosnmp"
	"reflect"
	"strconv"
	"strings"
)

func getitemvalue(g *gosnmp.GoSNMP, itemname string) (ret interface{}, err error) {
	if val, has := mapnameoid[itemname]; has {
		getval, err := g.Get([]string{val})
		if err != nil {
			return nil, err
		}
		ret = getval.Variables[0].Value
		fmt.Println(reflect.TypeOf(ret))
		switch ret.(type) {
		case []uint8:
			return string(ret.([]byte)), nil
		case uint:
			return int(ret.(uint)), nil
		}
		return ret, nil
	}
	return nil, fmt.Errorf("has no map oids for table")
}

func getInfo(g *gosnmp.GoSNMP, tabname string) (tablist []interface{}, err error) {
	if val, has := mapnameoidtable[tabname]; has {
		itemtype := reflect.ValueOf(val.Structtype).Type()
		refitem := reflect.New(itemtype).Elem()
		fmt.Println(refitem.Type())

		if val.Colums != refitem.NumField() {
			return nil, fmt.Errorf("colums is not equals to struct items")
		}

		oidlist := []string{}
		for inx := 1; inx <= val.Colums; inx++ {
			oidlist = append(oidlist, val.Oid+strconv.Itoa(inx))
		}

		for inx := 0; inx < 100; inx++ {
			ret, err := g.GetNext(oidlist)
			if err != nil {
				fmt.Println(err)
				return nil, err
			}

			for _, value := range ret.Variables {
				if strings.Index(value.Name, val.Oid) != 0 {
					return tablist, nil
				}
			}

			oidlist = []string{}
			for i, value := range ret.Variables {

				switch value.Value.(type) {
				case int:
					refitem.Field(i).SetInt(gosnmp.ToBigInt(value.Value).Int64())
				case uint:
					refitem.Field(i).SetInt(gosnmp.ToBigInt(value.Value).Int64())
				case string:
					refitem.Field(i).SetString(value.Value.(string))
				case []uint8:
					//refitem.Field(i).SetBytes(value.Value.([]byte))
					if temp1, bok := itemtype.Field(i).Tag.Lookup("snmp"); bok && (temp1 == "MacAddress"||temp1=="PhysAddress") {
						strmac := hex.EncodeToString(value.Value.([]byte))
						if len(strmac) >= 6 {
							strrealmac := strmac[0:2]
							for inx := 2; inx <= len(strmac)-2; inx += 2 {
								strrealmac += "-" + strmac[inx:inx+2]
							}
							refitem.Field(i).SetString(strrealmac)
						}
					} else {
						refitem.Field(i).SetString(string(value.Value.([]byte)))
					}
				default:
					fmt.Println(reflect.TypeOf(value.Value))
					panic("errrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr")
				}
				oidlist = append(oidlist, value.Name)
				//fmt.Println(value.Name)
				if strings.Index(value.Name, val.Oid) != 0 {
					return tablist, nil
				}
			}
			tablist = append(tablist, refitem.Interface())
			refitem = reflect.New(itemtype).Elem()
		}
		return tablist, nil
	}
	return nil, fmt.Errorf("has no map oids for table")
}

func Printoidtabletype(g *gosnmp.GoSNMP) {
	for key, table := range mapnameoidtable {
		fmt.Println(key, "------------------------------")
		oidlist := []string{}
		for inx := 1; inx <= table.Colums; inx++ {
			oidlist = append(oidlist, table.Oid+strconv.Itoa(inx))
		}
		ret, err := g.GetNext(oidlist)
		if err != nil {
			fmt.Println(err)
			return
		}
		for _, value := range ret.Variables {
			fmt.Println(value.Type, "\t", reflect.TypeOf(value.Value))
		}
		fmt.Println("")
	}
}


func Explicit(v reflect.Value, depth int) {
	if v.CanInterface() {
		t := v.Type()
		switch v.Kind() {
		case reflect.Ptr:
			Explicit(v.Elem(), depth)
		case reflect.Struct:
			fmt.Printf(strings.Repeat("\t", depth)+"%v %v {\n", t.Name(), t.Kind())
			for i := 0; i < v.NumField(); i++ {
				f := v.Field(i)
				if f.Kind() == reflect.Struct || f.Kind() == reflect.Ptr {
					fmt.Printf(strings.Repeat("\t", depth+1)+"%s %s : \n", t.Field(i).Name, f.Type())
					Explicit(f, depth+2)
				} else {
					if f.CanInterface() {
						fmt.Printf(strings.Repeat("\t", depth+1)+"%s %s : %v \n", t.Field(i).Name, f.Type(), f.Interface())
					} else {
						fmt.Printf(strings.Repeat("\t", depth+1)+"%s %s : %v \n", t.Field(i).Name, f.Type(), f)
					}
				}
			}
			fmt.Println(strings.Repeat("\t", depth) + "}")
		}
	} else {
		fmt.Printf(strings.Repeat("\t", depth)+"%+v\n", v)
	}
}
