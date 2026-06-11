package com.devops.lab.spring_petclinic_devops;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class PetController {

    @GetMapping("/pets")
    public String getPets() {
        return "Hola, esta es la API de mi proyecto DevOps!";
    }

    @GetMapping("/pets/error-test")
    public String causarError() {
        throw new RuntimeException("Error forzado para pruebas de Grafana");
    }
}