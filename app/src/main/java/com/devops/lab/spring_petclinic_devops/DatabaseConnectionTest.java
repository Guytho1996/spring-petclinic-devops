package com.devops.lab.spring_petclinic_devops;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;
import javax.sql.DataSource; // <--- Vuelve a poner javax.sql
import java.sql.Connection;

@Component
public class DatabaseConnectionTest implements CommandLineRunner {

    @Autowired
    private DataSource dataSource;

    @Override
    public void run(String... args) throws Exception {
        try (Connection connection = dataSource.getConnection()) {
            System.out.println("✅ ¡CONEXIÓN EXITOSA A SUPABASE!");
        } catch (Exception e) {
            System.err.println("❌ ERROR AL CONECTAR: " + e.getMessage());
        }
    }
}




