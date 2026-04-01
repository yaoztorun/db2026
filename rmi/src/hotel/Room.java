package hotel;

import java.io.Serializable;
import java.util.ArrayList;
import java.util.List;

public class Room implements Serializable {
    private static final long serialVersionUID = 1L;

    private Integer roomNumber;
    private List<BookingDetail> bookings;

    public Room(Integer roomNumber) {
        this.roomNumber = roomNumber;
        bookings = new ArrayList<BookingDetail>();
    }

    public Integer getRoomNumber() {
        return roomNumber;
    }

    public void setRoomNumber(Integer roomNumber) {
        this.roomNumber = roomNumber;
    }

    public List<BookingDetail> getBookings() {
        return bookings;
    }

    public void setBookings(List<BookingDetail> bookings) {
        this.bookings = bookings;
    }
}
